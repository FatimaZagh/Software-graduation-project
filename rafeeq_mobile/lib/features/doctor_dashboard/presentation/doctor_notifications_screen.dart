import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../utils/chat_notification_helpers.dart';
import '../data/doctor_portal_api.dart';
import '../data/doctor_workspace_api.dart';
import 'doctor_chat_room_screen.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kWorkspaceBlack = Color(0xFF0B0B0C);
const Color _kFieldFill = Color(0xFF1A1A18);

/// Doctor in-app notification center with deep-link to chat threads.
class DoctorNotificationsScreen extends StatefulWidget {
  const DoctorNotificationsScreen({
    super.key,
    required this.api,
  });

  final DoctorWorkspaceApi api;

  @override
  State<DoctorNotificationsScreen> createState() => _DoctorNotificationsScreenState();
}

class _DoctorNotificationsScreenState extends State<DoctorNotificationsScreen> {
  List<dynamic> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await DoctorPortalApi.getNotifications(widget.api.doctorUserId);
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _markRead(String id) async {
    await DoctorPortalApi.markNotificationRead(widget.api.doctorUserId, id);
    await _load();
  }

  Future<void> _handleTap(Map<String, dynamic> m) async {
    final id = m['_id']?.toString() ?? '';

    if (ChatNotificationHelpers.isMessageNotification(m)) {
      final patientUserId = ChatNotificationHelpers.patientUserIdFromNotification(m);
      if (patientUserId != null && patientUserId.isNotEmpty) {
        if (id.isNotEmpty && m['read'] != true) {
          await DoctorPortalApi.markNotificationRead(widget.api.doctorUserId, id);
        }
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => DoctorChatRoomScreen(
              api: widget.api,
              patientUserId: patientUserId,
              patientName: ChatNotificationHelpers.peerDisplayName(m),
            ),
          ),
        );
        await _load();
        return;
      }
    }

    if (id.isNotEmpty && m['read'] != true) {
      await _markRead(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kWorkspaceBlack,
      appBar: AppBar(
        backgroundColor: _kWorkspaceBlack,
        foregroundColor: _kGold,
        title: Text('Notifications', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGold))
          : _list.isEmpty
              ? Center(
                  child: Text(
                    'No notifications yet.',
                    style: GoogleFonts.urbanist(color: Colors.white54),
                  ),
                )
              : RefreshIndicator(
                  color: _kGold,
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _list.length,
                    itemBuilder: (_, i) {
                      final m = Map<String, dynamic>.from(_list[i] as Map);
                      final unread = m['read'] != true;
                      final isMessage = ChatNotificationHelpers.isMessageNotification(m);

                      return ListTile(
                        tileColor: unread ? _kFieldFill : null,
                        leading: Icon(
                          isMessage ? Icons.chat_bubble_outline : Icons.notifications_outlined,
                          color: isMessage ? _kGold : Colors.white54,
                        ),
                        title: Text(
                          m['title']?.toString() ?? '',
                          style: GoogleFonts.urbanist(
                            color: Colors.white,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          m['body']?.toString() ?? '',
                          style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
                        ),
                        trailing: unread
                            ? const Icon(Icons.chevron_right, color: _kGoldLight)
                            : const Icon(Icons.done, color: Colors.white38, size: 20),
                        onTap: () => _handleTap(m),
                      );
                    },
                  ),
                ),
    );
  }
}
