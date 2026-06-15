import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/chat_message_helpers.dart';
import '../../../widgets/rafeeq_chat_bubble.dart';
import '../data/doctor_portal_api.dart';
import '../data/doctor_workspace_api.dart';
import 'doctor_tab_pages.dart';
import 'patient_details_screen.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kFieldFill = Color(0xFF1A1A18);
const Color _kWorkspaceBlack = Color(0xFF0B0B0C);

/// Doctor view of a patient before / during in-app chat — profile, Rx actions, message thread.
class DoctorPatientChatProfileScreen extends StatefulWidget {
  const DoctorPatientChatProfileScreen({
    super.key,
    required this.api,
    required this.patientUserId,
    required this.patientName,
    required this.specialty,
    this.patientEmail,
  });

  final DoctorWorkspaceApi api;
  final String patientUserId;
  final String patientName;
  final String specialty;
  final String? patientEmail;

  @override
  State<DoctorPatientChatProfileScreen> createState() => _DoctorPatientChatProfileScreenState();
}

class _DoctorPatientChatProfileScreenState extends State<DoctorPatientChatProfileScreen> {
  final _messageCtrl = TextEditingController();
  final _chatAnchor = GlobalKey();
  List<Map<String, dynamic>> _messages = [];
  bool _loadingMessages = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loadingMessages = true);
    try {
      final list = await DoctorPortalApi.getChatMessages(widget.api.doctorUserId, widget.patientUserId);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loadingMessages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMessages = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _messageCtrl.clear();
    try {
      await DoctorPortalApi.postChatMessage(widget.api.doctorUserId, widget.patientUserId, text);
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _focusChat() {
    final ctx = _chatAnchor.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  Future<void> _writeEPrescription() async {
    await showPatientDiagnosisSheet(
      context,
      api: widget.api,
      patientUserId: widget.patientUserId,
      patientName: widget.patientName,
      specialty: widget.specialty,
    );
  }

  void _openPrescriptionHistory() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PatientDetailsScreen(
          api: widget.api,
          patientId: widget.patientUserId,
          patientName: widget.patientName,
          onNewExamination: (ctx) => showPatientDiagnosisSheet(
            ctx,
            api: widget.api,
            patientUserId: widget.patientUserId,
            patientName: widget.patientName,
            specialty: widget.specialty,
          ),
        ),
      ),
    );
  }

  Widget _profileHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _kGold.withValues(alpha: 0.2),
            child: Text(
              widget.patientName.isNotEmpty ? widget.patientName[0].toUpperCase() : '?',
              style: GoogleFonts.urbanist(color: _kGold, fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patientName,
                  style: GoogleFonts.urbanist(color: _kGoldLight, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.doctorPatientRecord}: ${widget.patientUserId}',
                  style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
                ),
                if (widget.patientEmail != null && widget.patientEmail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.patientEmail!.trim(),
                    style: GoogleFonts.urbanist(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatActionButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _focusChat,
        customBorder: const CircleBorder(),
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kGold.withValues(alpha: 0.12),
            border: Border.all(color: _kGold.withValues(alpha: 0.55)),
          ),
          padding: const EdgeInsets.all(14),
          child: const Icon(Icons.chat_bubble_outline, color: _kGoldLight, size: 26),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _kWorkspaceBlack,
      appBar: AppBar(
        backgroundColor: _kWorkspaceBlack,
        foregroundColor: _kGold,
        title: Text(
          widget.patientName,
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: [
                _profileHeader(l10n),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _chatActionButton(),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _writeEPrescription,
                        child: Text(
                          'Write E-Prescription',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kGoldLight,
                          side: BorderSide(color: _kGold.withValues(alpha: 0.65)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _openPrescriptionHistory,
                        child: Text(
                          'E-Prescription History',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _chatAnchor,
                  child: Text(
                    l10n.doctorChatTitle,
                    style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingMessages)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: _kGold)),
                  )
                else if (_messages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No messages yet. Use in-app chat to reach this patient.',
                      style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
                    ),
                  )
                else
                  ..._messages.map((m) {
                    final isMe = ChatMessageHelpers.isFromDoctor(m, widget.api.doctorUserId);
                    return RafeeqChatBubble(
                      isMe: isMe,
                      text: ChatMessageHelpers.bodyOf(m),
                      timestamp: ChatMessageHelpers.timestampOf(m),
                    );
                  }),
              ],
            ),
          ),
          Material(
            color: _kFieldFill,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageCtrl,
                        style: GoogleFonts.urbanist(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: l10n.doctorChatHint,
                          hintStyle: GoogleFonts.urbanist(color: Colors.white38, fontSize: 13),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.35),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _kGold.withValues(alpha: 0.35)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _kGold.withValues(alpha: 0.35)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _kGold),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _sendMessage,
                      icon: _sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _kGold),
                            )
                          : const Icon(Icons.send_rounded, color: _kGold),
                      tooltip: l10n.doctorSend,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
