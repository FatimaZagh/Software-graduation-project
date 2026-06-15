import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../data/patient_portal_api.dart';
import 'rafeeq_pseudo_ai_engine.dart';

const Color _kAiBg = Color(0xFF121212);
const Color _kAiCard = Color(0xFF1E1E1E);
const Color _kAiGold = Color(0xFFD4AF37);
const Color _kAiGrey = Color(0xFFB3B3B3);

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isHidden;
  final DateTime at;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isHidden = false,
    required this.at,
  });
}

/// Full-screen Rafeeq AI Medical Assistant — premium dark/gold healthcare chat.
class RafeeqAiMedicalAssistantScreen extends StatefulWidget {
  final String patientUserId;
  final String? preInjectedMedicationName;

  const RafeeqAiMedicalAssistantScreen({
    super.key,
    required this.patientUserId,
    this.preInjectedMedicationName,
  });

  @override
  State<RafeeqAiMedicalAssistantScreen> createState() => _RafeeqAiMedicalAssistantScreenState();
}

class _RafeeqAiMedicalAssistantScreenState extends State<RafeeqAiMedicalAssistantScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _typing = false;
  bool _loadingContext = true;
  Map<String, dynamic> _platformContext = {};

  @override
  void initState() {
    super.initState();
    _loadPlatformContext().then((_) {
      final med = widget.preInjectedMedicationName?.trim();
      if (med != null && med.isNotEmpty) {
        _sendHiddenMedicationQuery(med);
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadPlatformContext() async {
    try {
      final medsRes = await http.get(
        Uri.parse('$rafeeqApiBase/api/patients/${widget.patientUserId}/medications'),
      );
      final bookingsData = await PatientPortalApi.getMyBookings(widget.patientUserId);
      Map<String, dynamic>? healthProfile;
      try {
        healthProfile = await PatientPortalApi.getHealthProfile(widget.patientUserId);
      } catch (_) {}

      List<String> activeMeds = [];
      if (medsRes.statusCode == 200) {
        final decoded = jsonDecode(medsRes.body);
        if (decoded is Map) {
          final active = decoded['active'] as List? ?? [];
          activeMeds = [
            for (final m in active)
              if (m is Map) (m['medicationName'] ?? m['name'] ?? '').toString(),
          ].where((n) => n.isNotEmpty).toList();
        } else if (decoded is List) {
          activeMeds = [
            for (final m in decoded)
              if (m is Map) (m['medicationName'] ?? m['name'] ?? '').toString(),
          ].where((n) => n.isNotEmpty).toList();
        }
      }

      final bookingList = <Map<String, dynamic>>[
        for (final e in (bookingsData['confirmedBookings'] as List? ?? []))
          if (e is Map) Map<String, dynamic>.from(e),
        for (final e in (bookingsData['pendingBookings'] as List? ?? []))
          if (e is Map) Map<String, dynamic>.from(e),
      ];

      final upcoming = bookingList
          .where((b) {
            final status = b['status']?.toString().toLowerCase() ?? '';
            return !status.contains('cancel') && !status.contains('complete');
          })
          .take(5)
          .map((b) => {
                'date': b['appointmentDate'] ?? b['date'],
                'clinic': b['clinicName'] ?? b['clinic'],
                'doctor': b['doctorName'] ?? b['doctor'],
                'status': b['status'],
              })
          .toList();

      if (!mounted) return;
      setState(() {
        _platformContext = {
          'patientUserId': widget.patientUserId,
          'activeMedications': activeMeds,
          'upcomingAppointments': upcoming,
          if (healthProfile != null) 'healthProfile': healthProfile,
          if (widget.preInjectedMedicationName?.trim().isNotEmpty == true)
            'focusedMedication': widget.preInjectedMedicationName!.trim(),
        };
        _loadingContext = false;
      });
    } catch (e) {
      debugPrint('[Rafeeq AI] context load error: $e');
      if (!mounted) return;
      setState(() {
        _platformContext = {'patientUserId': widget.patientUserId};
        _loadingContext = false;
      });
    }
  }

  Map<String, dynamic> get _patientContext => {
        ..._platformContext,
        if (widget.preInjectedMedicationName?.trim().isNotEmpty == true) ...{
          'focusedMedication': widget.preInjectedMedicationName!.trim(),
          'medicationMode': true,
        },
      };

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _typing = false;
    });
    _input.clear();
  }

  Future<void> _sendHiddenMedicationQuery(String medicationName) async {
    final hiddenPrompt = 'Provide patient-friendly information for $medicationName';
    setState(() {
      _typing = true;
      _messages.add(_ChatMessage(
        text: hiddenPrompt,
        isUser: true,
        isHidden: true,
        at: DateTime.now(),
      ));
    });
    _scrollToEnd();
    await _dispatchLocalResponse(hiddenPrompt, medicationMode: true);
  }

  Future<void> _sendUserMessage() async {
    final text = _input.text.trim();
    if (text.isEmpty || _typing) return;

    _input.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, at: DateTime.now()));
      _typing = true;
    });
    _scrollToEnd();
    await _dispatchLocalResponse(text);
  }

  Future<void> _dispatchLocalResponse(String message, {bool medicationMode = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    final reply = generatePseudoMedicalResponse(
      message,
      patientContext: _patientContext,
      medicationMode: medicationMode,
    );

    setState(() {
      _messages.add(_ChatMessage(text: reply, isUser: false, at: DateTime.now()));
      _typing = false;
    });
    _scrollToEnd();
  }

  Future<void> _copyReply(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard', style: GoogleFonts.urbanist()),
        backgroundColor: _kAiCard,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final visibleMessages = _messages.where((m) => !m.isHidden).toList(growable: false);

    return Scaffold(
      backgroundColor: _kAiBg,
      appBar: AppBar(
        backgroundColor: _kAiBg,
        foregroundColor: _kAiGold,
        elevation: 0,
        title: Text(
          'Rafeeq AI Medical Assistant',
          style: GoogleFonts.urbanist(color: _kAiGold, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (_loadingContext)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kAiGold),
              ),
            ),
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _typing ? null : _clearChat,
            icon: const Icon(Icons.delete_sweep_outlined, color: _kAiGold),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: visibleMessages.isEmpty && !_typing
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.preInjectedMedicationName?.trim().isNotEmpty == true
                            ? 'Gathering information about ${widget.preInjectedMedicationName}...'
                            : 'Ask about medications, prescriptions, side effects, drug interactions, appointments, or clinic services.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.urbanist(color: _kAiGrey, fontSize: 14, height: 1.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    itemCount: visibleMessages.length + (_typing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_typing && index == visibleMessages.length) {
                        return _typingIndicator();
                      }
                      return _messageBubble(visibleMessages[index]);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: _kAiCard,
            child: const Text(
              '⚠️ AI-generated information. Consult your doctor or pharmacist before making medical decisions.',
              style: TextStyle(color: _kAiGrey, fontSize: 11, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            color: _kAiCard,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_typing && !_loadingContext,
                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                      cursorColor: _kAiGold,
                      decoration: InputDecoration(
                        hintText: 'Ask a healthcare question...',
                        hintStyle: GoogleFonts.urbanist(
                          color: _kAiGrey.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: _kAiBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _kAiGold.withValues(alpha: 0.45)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _kAiGold.withValues(alpha: 0.35)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _kAiGold, width: 1.2),
                        ),
                      ),
                      onSubmitted: (_) => _sendUserMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: _kAiGold,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _typing || _loadingContext ? null : _sendUserMessage,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.send_rounded, color: _kAiBg, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kAiGold),
          ),
          const SizedBox(width: 10),
          Text(
            'Rafeeq AI is typing...',
            style: GoogleFonts.urbanist(color: _kAiGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF2A2A2A) : _kAiCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUser ? Colors.white12 : _kAiGold.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    message.text,
                    style: GoogleFonts.urbanist(
                      color: isUser ? Colors.white : _kAiGold,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
                if (!isUser)
                  IconButton(
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => _copyReply(message.text),
                    icon: const Icon(Icons.copy_rounded, size: 16, color: _kAiGrey),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              _formatTime(message.at),
              style: GoogleFonts.urbanist(color: _kAiGrey.withValues(alpha: 0.75), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
