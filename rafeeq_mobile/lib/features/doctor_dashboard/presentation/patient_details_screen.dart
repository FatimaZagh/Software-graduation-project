import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/doctor_workspace_api.dart';
import '../data/patient_medical_profile.dart';

const Color _kWorkspaceBlack = Color(0xFF0B0B0C);
const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kFieldFill = Color(0xFF1A1A18);

/// Comprehensive chronological EMR / medical history for a patient.
class PatientDetailsScreen extends StatefulWidget {
  const PatientDetailsScreen({
    super.key,
    required this.api,
    required this.patientId,
    required this.patientName,
    this.onNewExamination,
  });

  final DoctorWorkspaceApi api;
  final String patientId;
  final String patientName;
  final Future<void> Function(BuildContext context)? onNewExamination;

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  PatientMedicalProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.api.getPatientFullHistory(
        patientUserId: widget.patientId,
        patientName: widget.patientName,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openExaminationSheet() async {
    if (!mounted || widget.patientId.trim().isEmpty || widget.onNewExamination == null) return;
    await widget.onNewExamination!(context);
    if (mounted) await _load();
  }

  TextStyle _labelStyle() => GoogleFonts.urbanist(color: _kGoldLight, fontSize: 12, fontWeight: FontWeight.w600);

  TextStyle _valueStyle() => GoogleFonts.urbanist(color: Colors.white, fontSize: 14);

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat.yMMMd().format(dt.toLocal());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF4CAF50);
      case 'In Progress':
        return const Color(0xFF7E57C2);
      case 'Cancelled':
      case 'cancelled_by_doctor':
      case 'cancelled_by_patient':
        return Colors.redAccent;
      case 'Prescription':
        return _kGold;
      default:
        return Colors.white54;
    }
  }

  Widget _buildPatientHeader(PatientMedicalProfile profile) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.patientName,
            style: GoogleFonts.urbanist(color: _kGold, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Patient ID: ${profile.patientId}',
            style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 6),
                    Text('Allergies', style: _labelStyle().copyWith(color: Colors.redAccent)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  profile.allergiesDisplay,
                  style: _valueStyle().copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Active medications: ${profile.activeMedicationCount}',
            style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _rxSubCard(VisitPrescriptionRecord rx) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rx.medicationName,
                  style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Rx',
                  style: GoogleFonts.urbanist(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (rx.dosage.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Dosage: ${rx.dosage}', style: _valueStyle().copyWith(fontSize: 13)),
          ],
          if (rx.frequency.isNotEmpty)
            Text('Frequency: ${rx.frequency}', style: _valueStyle().copyWith(fontSize: 13)),
          if (rx.duration.isNotEmpty)
            Text('Duration: ${rx.duration}', style: _valueStyle().copyWith(fontSize: 13)),
          if (rx.instructions.isNotEmpty)
            Text('Instructions: ${rx.instructions}', style: _valueStyle().copyWith(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPastVisitHistoryCard(PatientVisitHistoryEntry visit) {
    final dx = visit.diagnosis;
    final statusColor = _statusColor(visit.status);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _fmtDate(visit.visitDate),
                  style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  visit.status,
                  style: GoogleFonts.urbanist(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (dx != null) ...[
            const SizedBox(height: 12),
            Text('Clinical Diagnosis', style: _labelStyle()),
            const SizedBox(height: 6),
            if (dx.condition.isNotEmpty) Text('Condition: ${dx.condition}', style: _valueStyle()),
            if (dx.symptoms.isNotEmpty)
              Text('Symptoms: ${dx.symptoms.join(', ')}', style: _valueStyle().copyWith(fontSize: 13)),
            if (dx.severity.isNotEmpty) Text('Severity: ${dx.severity}', style: _valueStyle().copyWith(fontSize: 13)),
            if (dx.treatmentPlan.isNotEmpty)
              Text('Treatment Plan: ${dx.treatmentPlan}', style: _valueStyle().copyWith(fontSize: 13)),
          ],
          if (visit.prescriptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Prescriptions Issued', style: _labelStyle()),
            ...visit.prescriptions.map(_rxSubCard),
          ],
          if (dx == null && visit.prescriptions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('No clinical details recorded for this visit.', style: _valueStyle().copyWith(color: Colors.white54)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kWorkspaceBlack,
      appBar: AppBar(
        backgroundColor: _kWorkspaceBlack,
        foregroundColor: _kGold,
        elevation: 0,
        title: Text(
          '${widget.patientName} — Medical Record',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      floatingActionButton: widget.onNewExamination == null
          ? null
          : FloatingActionButton.extended(
        onPressed: widget.patientId.trim().isEmpty ? null : _openExaminationSheet,
        backgroundColor: _kGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.medical_services_outlined),
        label: Text('New Examination', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: GoogleFonts.urbanist(color: Colors.redAccent), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _profile == null || _profile!.visits.isEmpty
                  ? RefreshIndicator(
                      color: _kGold,
                      onRefresh: _load,
                      child: ListView(
                        children: [
                          if (_profile != null) _buildPatientHeader(_profile!),
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              'No historical data found for this profile.',
                              style: GoogleFonts.urbanist(color: Colors.white54),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: _kGold,
                      onRefresh: _load,
                      child: Column(
                        children: [
                          _buildPatientHeader(_profile!),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Visit Timeline',
                                style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _profile!.visits.length,
                              itemBuilder: (_, index) => _buildPastVisitHistoryCard(_profile!.visits[index]),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
