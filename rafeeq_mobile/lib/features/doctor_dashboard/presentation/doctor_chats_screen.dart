import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../data/doctor_portal_api.dart';
import '../data/doctor_workspace_api.dart';
import 'doctor_chat_room_screen.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kGlass = Color(0xE6101A18);
const Color _kWorkspaceBlack = Color(0xFF0B0B0C);

/// Global list of patient conversations for the logged-in doctor.
class DoctorChatsScreen extends StatefulWidget {
  const DoctorChatsScreen({super.key, required this.api});

  final DoctorWorkspaceApi api;

  @override
  State<DoctorChatsScreen> createState() => _DoctorChatsScreenState();
}

class _DoctorChatsScreenState extends State<DoctorChatsScreen> {
  List<dynamic> _patients = [];
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
      final list = await DoctorPortalApi.getChatPatients(widget.api.doctorUserId);
      if (!mounted) return;
      setState(() {
        _patients = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _openChat(Map<String, dynamic> patient) {
    final patientUserId = patient['_id']?.toString() ?? patient['userId']?.toString() ?? '';
    if (patientUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient ID missing — cannot open chat.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DoctorChatRoomScreen(
          api: widget.api,
          patientUserId: patientUserId,
          patientName: patient['name']?.toString() ?? 'Patient',
        ),
      ),
    ).then((_) => _load());
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
          l10n.doctorNavMessages,
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: _kGoldLight),
          ),
        ],
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
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
                          child: Text(l10n.doctorRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: _kGold,
                  onRefresh: _load,
                  child: _patients.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                children: [
                                  Icon(Icons.chat_bubble_outline, size: 48, color: _kGold.withValues(alpha: 0.5)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No conversations yet',
                                    style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w700, fontSize: 17),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'When patients message you, their chats will appear here. You can also open a chat from an ADR report.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.urbanist(color: Colors.white54, height: 1.45),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _patients.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final p = Map<String, dynamic>.from(_patients[index] as Map);
                            final name = p['name']?.toString() ?? 'Patient';
                            final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _openChat(p),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: _kGlass,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _kGold.withValues(alpha: 0.2),
                                      child: Text(initial, style: const TextStyle(color: _kGold, fontWeight: FontWeight.w700)),
                                    ),
                                    title: Text(name, style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      p['email']?.toString() ?? '',
                                      style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
                                    ),
                                    trailing: const Icon(Icons.chevron_right, color: _kGold),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
