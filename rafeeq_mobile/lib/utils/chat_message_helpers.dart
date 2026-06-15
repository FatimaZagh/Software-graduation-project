/// Shared helpers for doctor/patient in-app chat API payloads.
class ChatMessageHelpers {
  ChatMessageHelpers._();

  static List<Map<String, dynamic>> parseList(dynamic raw) {
    if (raw is List) {
      return [
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    if (raw is Map) {
      for (final key in ['messages', 'data', 'items', 'results']) {
        final nested = raw[key];
        if (nested is List) {
          return [
            for (final item in nested)
              if (item is Map) Map<String, dynamic>.from(item),
          ];
        }
      }
    }
    return [];
  }

  static String idOf(dynamic value) {
    if (value == null) return '';
    if (value is Map && value['_id'] != null) return value['_id'].toString();
    return value.toString();
  }

  static String bodyOf(Map<String, dynamic> m) {
    for (final key in ['body', 'text', 'message', 'content']) {
      final v = m[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final enc = m['bodyEnc'];
    if (enc is Map) {
      final cipher = enc['cipherTextB64']?.toString().trim();
      if (cipher != null && cipher.isNotEmpty) {
        // Encrypted payload — backend should decrypt; keep key parity for diagnostics.
        return m['body']?.toString().trim() ?? '';
      }
    }
    return '';
  }

  static DateTime? timestampOf(Map<String, dynamic> m) {
    for (final key in ['createdAt', 'timestamp', 'sentAt']) {
      final raw = m[key];
      if (raw == null) continue;
      if (raw is DateTime) return raw.toLocal();
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  static bool isFromDoctor(Map<String, dynamic> m, String doctorUserId) {
    final doctorId = doctorUserId.trim();
    final senderId = idOf(m['senderId']);
    if (senderId.isNotEmpty && senderId == doctorId) return true;
    return m['senderRole']?.toString().toLowerCase() == 'doctor';
  }

  static bool isFromPatient(Map<String, dynamic> m, String patientUserId) {
    final patientId = patientUserId.trim();
    final senderId = idOf(m['senderId']);
    if (senderId.isNotEmpty && senderId == patientId) return true;
    return m['senderRole']?.toString().toLowerCase() == 'patient';
  }

  static bool listsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final leftId = idOf(a[i]['_id']);
      final rightId = idOf(b[i]['_id']);
      if (leftId != rightId) return false;
      if (bodyOf(a[i]) != bodyOf(b[i])) return false;
    }
    return true;
  }
}
