/// Detect message/chat notifications and extract peer IDs for deep-link navigation.
class ChatNotificationHelpers {
  ChatNotificationHelpers._();

  static bool isMessageNotification(Map<String, dynamic> notification) {
    final type = notification['type']?.toString().toLowerCase() ?? '';
    if (type == 'message' || type == 'chat') return true;

    final title = notification['title']?.toString().toLowerCase() ?? '';
    if (title.contains('message') || title.contains('sent you')) return true;

    final body = notification['body']?.toString().toLowerCase() ?? '';
    return body.contains('message');
  }

  static Map<String, dynamic> metaOf(Map<String, dynamic> notification) {
    final meta = notification['meta'];
    if (meta is Map) return Map<String, dynamic>.from(meta);
    return {};
  }

  static String? doctorUserIdFromNotification(Map<String, dynamic> notification) {
    final meta = metaOf(notification);
    for (final key in ['doctorUserId', 'doctorId']) {
      final id = meta[key]?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  static String? patientUserIdFromNotification(Map<String, dynamic> notification) {
    final meta = metaOf(notification);
    for (final key in ['patientUserId', 'patientId']) {
      final id = meta[key]?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  /// Resolves the chat peer for the logged-in user from notification meta.
  static ({String senderId, String receiverId})? chatParticipants({
    required Map<String, dynamic> notification,
    required String currentUserId,
    required bool currentUserIsDoctor,
  }) {
    final meta = metaOf(notification);
    final senderId = meta['senderId']?.toString().trim() ?? '';
    final receiverId = meta['receiverId']?.toString().trim() ?? '';
    if (senderId.isNotEmpty && receiverId.isNotEmpty) {
      return (senderId: senderId, receiverId: receiverId);
    }

    if (currentUserIsDoctor) {
      final patientId = patientUserIdFromNotification(notification);
      if (patientId == null || patientId.isEmpty) return null;
      return (senderId: patientId, receiverId: currentUserId);
    }

    final doctorId = doctorUserIdFromNotification(notification);
    if (doctorId == null || doctorId.isEmpty) return null;
    return (senderId: currentUserId, receiverId: doctorId);
  }

  static String peerDisplayName(Map<String, dynamic> notification) {
    final title = notification['title']?.toString().trim() ?? '';
    if (title.isEmpty) return 'Conversation';

    final sentYou = RegExp(r'^(.+?)\s+sent you', caseSensitive: false).firstMatch(title);
    if (sentYou != null) {
      final name = sentYou.group(1)?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return title;
  }
}
