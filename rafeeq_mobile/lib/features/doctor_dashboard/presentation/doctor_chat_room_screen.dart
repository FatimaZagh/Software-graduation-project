import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/chat_message_helpers.dart';
import '../../../widgets/rafeeq_chat_bubble.dart';
import '../data/doctor_portal_api.dart';
import '../data/doctor_workspace_api.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kFieldFill = Color(0xFF1A1A18);
const Color _kWorkspaceBlack = Color(0xFF0B0B0C);

/// In-app chat thread between doctor and a single patient.
class DoctorChatRoomScreen extends StatefulWidget {
  const DoctorChatRoomScreen({
    super.key,
    required this.api,
    required this.patientUserId,
    required this.patientName,
    this.initialDraft,
    this.contextBanner,
  });

  final DoctorWorkspaceApi api;
  final String patientUserId;
  final String patientName;
  final String? initialDraft;
  final String? contextBanner;

  @override
  State<DoctorChatRoomScreen> createState() => _DoctorChatRoomScreenState();
}

class _DoctorChatRoomScreenState extends State<DoctorChatRoomScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _loadError;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft?.trim();
    if (draft != null && draft.isNotEmpty) {
      _messageCtrl.text = draft;
    }
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final list = await DoctorPortalApi.getChatMessages(widget.api.doctorUserId, widget.patientUserId);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
        _loadError = null;
      });
      if (list.isNotEmpty) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
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
        _messageCtrl.text = text;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final banner = widget.contextBanner?.trim();

    return Scaffold(
      backgroundColor: _kWorkspaceBlack,
      appBar: AppBar(
        backgroundColor: _kWorkspaceBlack,
        foregroundColor: _kGold,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.patientName,
              style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              l10n.doctorChatTitle,
              style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadMessages,
            icon: const Icon(Icons.refresh, color: _kGoldLight),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          if (banner != null && banner.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _kGold.withValues(alpha: 0.12),
              child: Text(
                banner,
                style: GoogleFonts.urbanist(color: _kGoldLight, fontSize: 12, height: 1.35),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kGold))
                : _loadError != null && _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_loadError!, textAlign: TextAlign.center, style: GoogleFonts.urbanist(color: Colors.white54)),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: () => _loadMessages(), child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No messages yet. Send a message to start the conversation.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 14),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: _kGold,
                        onRefresh: () => _loadMessages(),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          itemCount: _messages.length,
                          itemBuilder: (_, index) {
                            final m = _messages[index];
                            final isMe = ChatMessageHelpers.isFromDoctor(m, widget.api.doctorUserId);
                            return RafeeqChatBubble(
                              isMe: isMe,
                              text: ChatMessageHelpers.bodyOf(m),
                              timestamp: ChatMessageHelpers.timestampOf(m),
                            );
                          },
                        ),
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
                        maxLines: 3,
                        minLines: 1,
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
