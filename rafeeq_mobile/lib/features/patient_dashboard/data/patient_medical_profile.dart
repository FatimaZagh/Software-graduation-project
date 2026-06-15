/// Parsed patient medical profile from GET /medical-records.
class PatientMedicalEncounter {
  const PatientMedicalEncounter({
    required this.id,
    this.visitDate,
    required this.doctorName,
    required this.clinicName,
    required this.chiefComplaint,
    required this.diagnosis,
    required this.prescribedMedications,
    required this.vitalSigns,
    required this.notes,
  });

  final String id;
  final DateTime? visitDate;
  final String doctorName;
  final String clinicName;
  final String chiefComplaint;
  final String diagnosis;
  final List<String> prescribedMedications;
  final Map<String, dynamic> vitalSigns;
  final String notes;

  factory PatientMedicalEncounter.fromJson(Map<String, dynamic> json) {
    final visitRaw = json['visitDate']?.toString();
    return PatientMedicalEncounter(
      id: json['id']?.toString() ?? '',
      visitDate: visitRaw != null && visitRaw.isNotEmpty ? DateTime.tryParse(visitRaw) : null,
      doctorName: json['doctorName']?.toString().trim() ?? '—',
      clinicName: json['clinicName']?.toString().trim() ?? '—',
      chiefComplaint: json['chiefComplaint']?.toString().trim() ?? '',
      diagnosis: json['diagnosis']?.toString().trim() ?? '',
      prescribedMedications: _stringList(json['prescribedMedications']),
      vitalSigns: json['vitalSigns'] is Map
          ? Map<String, dynamic>.from(json['vitalSigns'] as Map)
          : <String, dynamic>{},
      notes: json['notes']?.toString().trim() ?? '',
    );
  }
}

class PatientMedicalProfile {
  const PatientMedicalProfile({
    required this.bloodType,
    required this.allergies,
    required this.chronicConditions,
    required this.encounters,
  });

  final String bloodType;
  final List<String> allergies;
  final List<String> chronicConditions;
  final List<PatientMedicalEncounter> encounters;

  factory PatientMedicalProfile.fromJson(Map<String, dynamic> json) {
    return PatientMedicalProfile(
      bloodType: json['bloodType']?.toString().trim() ?? '',
      allergies: _stringList(json['allergies']),
      chronicConditions: _stringList(json['chronicConditions'] ?? json['chronicDiseases']),
      encounters: [
        for (final item in (json['encounters'] as List<dynamic>? ?? []))
          if (item is Map) PatientMedicalEncounter.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return [];
  return [
    for (final item in raw)
      if (item != null && item.toString().trim().isNotEmpty) item.toString().trim(),
  ];
}
