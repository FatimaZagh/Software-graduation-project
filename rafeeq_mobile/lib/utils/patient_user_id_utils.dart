/// Resolves a MongoDB user `_id` from heterogeneous appointment / patient API maps.
String resolvePatientUserId(Map<dynamic, dynamic> source) {
  for (final key in ['patientUserId', 'patientId']) {
    final resolved = mongoIdFromDynamic(source[key]);
    if (resolved.isNotEmpty) return resolved;
  }

  final patient = source['patient'];
  if (patient is Map) {
    for (final key in ['_id', 'id', 'userId', 'sId']) {
      final resolved = mongoIdFromDynamic(patient[key]);
      if (resolved.isNotEmpty) return resolved;
    }
  }

  return '';
}

/// Parses a single dynamic field into a 24-char hex MongoDB ObjectId string.
String mongoIdFromDynamic(dynamic value) {
  if (value == null) return '';
  if (value is Map) {
    for (final key in ['_id', 'id', 'userId', 'sId']) {
      final nested = mongoIdFromDynamic(value[key]);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') return '';
  return isMongoObjectId(text) ? text : '';
}

bool isMongoObjectId(String value) {
  return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value.trim());
}
