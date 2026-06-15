import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/patient_portal_api.dart';
import '../patient_theme.dart';

class _ChatEntry {
  final String text;
  final bool isUser;
  final bool isSearching;

  const _ChatEntry({required this.text, required this.isUser, this.isSearching = false});
}

/// Inline Rafeeq AI Medical Assistant — dark & gold, context-locked to selected medication.
class RafeeqMedicationAiPanel extends StatefulWidget {
  final String patientUserId;
  final String? selectedMedicationName;
  final ValueChanged<String>? onMedicationSelected;

  const RafeeqMedicationAiPanel({
    super.key,
    required this.patientUserId,
    this.selectedMedicationName,
    this.onMedicationSelected,
  });

  @override
  RafeeqMedicationAiPanelState createState() => RafeeqMedicationAiPanelState();
}

class RafeeqMedicationAiPanelState extends State<RafeeqMedicationAiPanel> {
  final List<_ChatEntry> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _expanded = true;
  bool _loading = false;

  static const _disclaimer =
      'This is AI-generated educational information. Always consult your doctor before making medical decisions.';

  static const _quickSuggestions = [
    'What are the side effects?',
    'When should I take it?',
    'Are there food interactions?',
  ];

  static const _chipFill = Color(0xFF1E2421);

  String? get _activeMedication =>
      widget.selectedMedicationName?.trim().isNotEmpty == true
          ? widget.selectedMedicationName!.trim()
          : null;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

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

  void searchMedication(String medicationName) {
    final name = medicationName.trim();
    if (name.isEmpty) return;
    widget.onMedicationSelected?.call(name);
    setState(() {
      _expanded = true;
      _messages.add(_ChatEntry(
        text: 'Searching details for $name...\nChecking FDA records and medical sources.',
        isUser: true,
        isSearching: true,
      ));
      _loading = true;
    });
    _scrollToEnd();
    _fetchAnswer(currentMedication: name);
  }

  Future<void> _submitMessage(String q) async {
    final text = q.trim();
    if (text.isEmpty || _loading) return;

    final locked = _activeMedication;
    if (locked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select a medication above to ask follow-up questions.',
            style: GoogleFonts.urbanist(),
          ),
          backgroundColor: const Color(0xFF3A2A10),
        ),
      );
      return;
    }

    setState(() {
      _messages.add(_ChatEntry(text: text, isUser: true));
      _loading = true;
    });
    _scrollToEnd();
    await _fetchAnswer(message: text, currentMedication: locked);
  }

  Future<void> _sendManual() async {
    final q = _input.text.trim();
    if (q.isEmpty || _loading) return;
    _input.clear();
    await _submitMessage(q);
  }

  void _onSuggestionTap(String question) {
    if (_loading) return;
    _submitMessage(question);
  }

  Future<void> _fetchAnswer({
    String? message,
    String? question,
    String? currentMedication,
    String? medicationName,
  }) async {
    try {
      final med = currentMedication ?? medicationName ?? _activeMedication;
      final prompt = (message ?? question)?.trim();
      final apiMessage = prompt?.isNotEmpty == true
          ? prompt!
          : 'Provide patient-friendly information for $med';
      final answer = await PatientPortalApi.postAiChat(
        message: apiMessage,
        patientContext: {
          'patientUserId': widget.patientUserId,
          if (med != null && med.isNotEmpty) 'focusedMedication': med,
        },
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatEntry(text: answer, isUser: false));
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[Rafeeq AI Panel] EXCEPTION: $e');
      debugPrint('[Rafeeq AI Panel] EXCEPTION stack: $st');
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatEntry(
          text: 'Unable to reach the assistant. Please try again later.\n($e)',
          isUser: false,
        ));
        _loading = false;
      });
    }
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final panelHeight = _expanded ? MediaQuery.sizeOf(context).height * 0.42 : 56.0;
    final locked = _activeMedication;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      height: panelHeight,
      decoration: BoxDecoration(
        color: kPatientSheetBg,
        border: Border(top: BorderSide(color: Colors.amber.withValues(alpha: 0.55), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: kPatientGold.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: kPatientGold, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rafeeq AI Medical Assistant',
                        style: GoogleFonts.urbanist(
                          color: kPatientGoldLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (locked != null && _expanded)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: Colors.amber.shade300),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                locked,
                                style: GoogleFonts.urbanist(color: Colors.amber, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: kPatientGold,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          locked == null
                              ? 'Tap a medication name above to lock context, then ask follow-up questions.'
                              : 'Context locked to $locked. Ask about side effects, timing, or storage.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (_loading && i == _messages.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.amber.shade300,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  locked != null && _messages.last.isUser && !_messages.last.isSearching
                                      ? 'Answering in context of $locked...'
                                      : 'Checking FDA records and medical sources...',
                                  style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }
                        final m = _messages[i];
                        return _bubble(m);
                      },
                    ),
            ),
            if (locked != null) _buildSuggestionChips(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(
                _disclaimer,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  color: kPatientGoldLight.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_loading,
                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                      cursorColor: kPatientGold,
                      decoration: InputDecoration(
                        hintText: locked == null
                            ? 'Select a medication first...'
                            : 'Ask about $locked...',
                        hintStyle: GoogleFonts.urbanist(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: kPatientFieldFill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.35)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.amber, width: 1.2),
                        ),
                      ),
                      onSubmitted: (_) => _sendManual(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: kPatientGoldDeep,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _loading ? null : _sendManual,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.send_rounded, color: kPatientWorkspaceBlack, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        itemCount: _quickSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = _quickSuggestions[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _loading ? null : () => _onSuggestionTap(label),
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                decoration: BoxDecoration(
                  color: _chipFill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    label,
                    style: GoogleFonts.urbanist(
                      color: Colors.amber.shade200,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bubble(_ChatEntry m) {
    final isUser = m.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.88),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF2A322E)
              : kPatientGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUser
                ? Colors.white12
                : Colors.amber.withValues(alpha: m.isSearching ? 0.7 : 0.45),
            width: isUser ? 0.8 : 1,
          ),
        ),
        child: Text(
          m.text,
          style: GoogleFonts.urbanist(
            color: isUser ? Colors.white70 : kPatientGoldLight,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
