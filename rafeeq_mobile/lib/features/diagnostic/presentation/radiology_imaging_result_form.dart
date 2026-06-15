import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);

InputDecoration _readOnlyDec(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _kGold.withValues(alpha: 0.85), fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _kGold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _kGold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
    );

InputDecoration _notesDec() => InputDecoration(
      labelText: 'Technician Notes',
      hintText: 'Image quality satisfactory. Patient completed examination successfully.',
      hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
      labelStyle: TextStyle(color: _kGold.withValues(alpha: 0.9), fontSize: 12),
      alignLabelWithHint: true,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _kGold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _kGold),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );

String formatImagingExamDate(DateTime dt) =>
    DateFormat('EEEE, MMMM d, yyyy · h:mm a').format(dt.toLocal());

String mimeForImagingExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'dcm':
    case 'dicom':
      return 'application/dicom';
    default:
      return 'application/octet-stream';
  }
}

IconData iconForImagingExtension(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (lower.endsWith('.dcm') || lower.endsWith('.dicom')) return Icons.medical_services_outlined;
  if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return Icons.image_outlined;
  }
  return Icons.attach_file;
}

/// Per-order imaging submission state (notes + attachment).
class RadiologyImagingFormState {
  RadiologyImagingFormState();

  final TextEditingController notesController = TextEditingController();
  String? attachmentDataUrl;
  String? attachmentName;
  String? attachmentMime;

  Future<void> pickAttachment() async {
    final r = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['dcm', 'dicom', 'pdf', 'png', 'jpg', 'jpeg'],
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final ext = (f.extension ?? 'pdf').toLowerCase();
    final mime = mimeForImagingExtension(ext);
    attachmentDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    attachmentName = f.name;
    attachmentMime = mime;
  }

  Map<String, dynamic> buildPayload({
    required Map<String, dynamic> order,
    required String technicianName,
  }) {
    final now = DateTime.now();
    return {
      'patientId': order['patientUserId']?.toString() ?? '',
      'examDate': now.toIso8601String(),
      'examDateDisplay': formatImagingExamDate(now),
      'technicianName': technicianName,
      'examType': order['modality']?.toString() ?? '',
      'bodyPartExamined': order['studyName']?.toString() ?? '',
      'studyName': order['studyName']?.toString() ?? '',
      'modality': order['modality']?.toString() ?? '',
      'technicianNotes': notesController.text.trim(),
      if (attachmentName != null) 'attachmentName': attachmentName,
      if (attachmentMime != null) 'attachmentMimeType': attachmentMime,
      'hasAttachment': attachmentDataUrl != null,
    };
  }

  String toResultAnalysisJson(Map<String, dynamic> order, String technicianName) =>
      jsonEncode(buildPayload(order: order, technicianName: technicianName));

  bool get canSubmit => attachmentDataUrl != null || notesController.text.trim().isNotEmpty;

  void clearAttachment() {
    attachmentDataUrl = null;
    attachmentName = null;
    attachmentMime = null;
  }

  void dispose() => notesController.dispose();
}

/// Imaging fulfillment form — auto-filled metadata, optional technician notes, file upload.
class RadiologyImagingResultForm extends StatelessWidget {
  const RadiologyImagingResultForm({
    super.key,
    required this.order,
    required this.technicianName,
    required this.formState,
    required this.onChanged,
  });

  final Map<String, dynamic> order;
  final String technicianName;
  final RadiologyImagingFormState formState;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final patientId = order['patientUserId']?.toString() ?? '—';
    final examType = order['modality']?.toString() ?? '—';
    final bodyPart = order['studyName']?.toString() ?? '—';
    final examDateDisplay = formatImagingExamDate(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'IMAGING REPORT',
          style: GoogleFonts.poppins(
            color: _kGold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: patientId,
          enabled: false,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          decoration: _readOnlyDec('Patient ID'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: examDateDisplay,
          enabled: false,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          decoration: _readOnlyDec('Exam Date'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: technicianName.isNotEmpty ? technicianName : 'Technician',
          enabled: false,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          decoration: _readOnlyDec('Technician Name'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: examType,
          enabled: false,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          decoration: _readOnlyDec('Exam Type'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: bodyPart,
          enabled: false,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          decoration: _readOnlyDec('Body Part Examined'),
        ),
        const SizedBox(height: 14),
        Text(
          'ATTACHMENT',
          style: GoogleFonts.poppins(color: _kGold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _kGoldLight,
            side: BorderSide(color: _kGold.withValues(alpha: 0.65)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          ),
          onPressed: () async {
            await formState.pickAttachment();
            onChanged();
          },
          icon: Icon(
            formState.attachmentName != null ? Icons.check_circle_outline : Icons.upload_file,
            color: _kGold,
            size: 20,
          ),
          label: Text(
            formState.attachmentName != null ? 'Replace imaging file' : 'Browse DICOM / PDF / Image',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        if (formState.attachmentName != null) ...[
          const SizedBox(height: 8),
          Material(
            color: _kGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            child: ListTile(
              dense: true,
              tileColor: Colors.transparent,
              leading: Icon(iconForImagingExtension(formState.attachmentName!), color: _kGold),
              title: Text(
                formState.attachmentName!,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                formState.attachmentMime ?? '',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
              ),
              trailing: IconButton(
                icon: Icon(Icons.close, color: Colors.redAccent.withValues(alpha: 0.85), size: 20),
                onPressed: () {
                  formState.clearAttachment();
                  onChanged();
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'TECHNICIAN NOTES (OPTIONAL)',
          style: GoogleFonts.poppins(color: _kGold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        Text(
          'Technical quality only — no medical diagnosis.',
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: formState.notesController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _notesDec(),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
