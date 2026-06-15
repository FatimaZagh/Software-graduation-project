import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../../../tenant_state.dart';
import 'doctor_session.dart';
import '../presentation/doctor_prescribe_screen.dart';
import 'patient_medical_profile.dart';

/// Clinical doctor workspace API — `/api/doctor/*` with org scope headers.
class DoctorWorkspaceApi {
  DoctorWorkspaceApi({required this.doctorUserId});

  final String doctorUserId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-user-id': doctorUserId,
        if (TenantState.instance.orgId.isNotEmpty) 'x-org-id': TenantState.instance.orgId,
        if (DoctorSession.instance.token.isNotEmpty)
          'Authorization': 'Bearer ${DoctorSession.instance.token}',
      };

  Uri _u(String path, [Map<String, String>? q]) {
    final base = Uri.parse('$rafeeqApiBase/api/doctor$path');
    if (q == null || q.isEmpty) return base;
    return base.replace(queryParameters: q);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final r = await http.get(_u(path, query), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode == 403) throw Exception('Access denied: ${r.body}');
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final r = await http.post(_u(path), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (r.statusCode == 403) throw Exception('Access denied: ${r.body}');
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final r = await http.put(_u(path), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (r.statusCode == 403) throw Exception('Access denied: ${r.body}');
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final r = await http.patch(_u(path), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 25));
    if (r.statusCode == 403) throw Exception('Access denied: ${r.body}');
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> dashboardStats() async =>
      Map<String, dynamic>.from(await get('/dashboard/stats') as Map);

  Future<List<dynamic>> todayQueue() async {
    final d = await get('/queue/today');
    return d is List ? d : [];
  }

  /// Patient-submitted adverse drug reports for this doctor (and org-unassigned queue).
  Future<List<dynamic>> adverseReports({bool criticalOnly = false}) async {
    final d = await get('/adverse-reports', query: criticalOnly ? {'criticalOnly': 'true'} : null);
    return d is List ? d : [];
  }

  Future<Map<String, dynamic>> patchAdverseReport(
    String reportId, {
    String? status,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
    };
    return Map<String, dynamic>.from(await patch('/adverse-reports/$reportId', body) as Map);
  }

  /// Marks an ADR alert as reviewed when the doctor opens it from the dashboard.
  Future<Map<String, dynamic>> acknowledgeADRAlert(String reportId) async =>
      patchAdverseReport(reportId, status: 'Reviewed');

  Future<Map<String, dynamic>> proposeAdverseMedicationSuspension(
    String reportId, {
    String? notes,
  }) async =>
      Map<String, dynamic>.from(
        await post('/adverse-reports/$reportId/propose-suspension', {
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        }) as Map,
      );

  Future<Map<String, dynamic>> getAdverseReportDetail(String reportId) async =>
      Map<String, dynamic>.from(await get('/adverse-reports/$reportId/detail') as Map);

  Future<Map<String, dynamic>> patchAdverseWorkflow(String reportId, String workflowStatus) async =>
      Map<String, dynamic>.from(
        await patch('/adverse-reports/$reportId/workflow', {'workflowStatus': workflowStatus}) as Map,
      );

  Future<Map<String, dynamic>> postAdrMarkEmergency(String reportId) async =>
      Map<String, dynamic>.from(await post('/adverse-reports/$reportId/mark-emergency', {}) as Map);

  Future<Map<String, dynamic>> postAdrStopMedication(String reportId, {String? reason}) async =>
      Map<String, dynamic>.from(
        await post('/adverse-reports/$reportId/stop-medication', {
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        }) as Map,
      );

  Future<Map<String, dynamic>> postAdrModifyMedication(
    String reportId, {
    String? dosage,
    String? frequency,
    String? notes,
  }) async =>
      Map<String, dynamic>.from(
        await post('/adverse-reports/$reportId/modify-medication', {
          if (dosage != null) 'dosage': dosage,
          if (frequency != null) 'frequency': frequency,
          if (notes != null) 'notes': notes,
        }) as Map,
      );

  Future<Map<String, dynamic>> postAdrReplaceMedication(
    String reportId, {
    required String replacementName,
    String? replacementDosage,
    String? replacementFrequency,
    String? notes,
  }) async =>
      Map<String, dynamic>.from(
        await post('/adverse-reports/$reportId/replace-medication', {
          'replacementName': replacementName,
          if (replacementDosage != null) 'replacementDosage': replacementDosage,
          if (replacementFrequency != null) 'replacementFrequency': replacementFrequency,
          if (notes != null) 'notes': notes,
        }) as Map,
      );

  Future<Map<String, dynamic>> postAdrErRedirect(String reportId) async =>
      Map<String, dynamic>.from(await post('/adverse-reports/$reportId/er-redirect', {}) as Map);

  Future<Map<String, dynamic>> postAdrClinicalNotes(String reportId, String text) async =>
      Map<String, dynamic>.from(
        await post('/adverse-reports/$reportId/clinical-notes', {'text': text}) as Map,
      );

  Future<Map<String, dynamic>> postAdrAllergyProfile(
    String reportId, {
    String? drugName,
    String? drugClass,
    String? severity,
  }) async =>
      Map<String, dynamic>.from(
        await post('/adverse-reports/$reportId/allergy-profile', {
          if (drugName != null) 'drugName': drugName,
          if (drugClass != null) 'drugClass': drugClass,
          if (severity != null) 'severity': severity,
        }) as Map,
      );

  Future<void> setAvailability(String status) async {
    await put('/availability', {'status': status});
  }

  Future<Map<String, dynamic>> profile() async =>
      Map<String, dynamic>.from(await get('/profile') as Map);

  Future<List<dynamic>> patients({String? q}) async {
    final d = await get('/patients', query: q != null && q.isNotEmpty ? {'q': q} : null);
    return d is List ? d : [];
  }

  Future<Map<String, dynamic>> patientEmr(String patientUserId) async =>
      Map<String, dynamic>.from(await get('/patients/$patientUserId') as Map);

  Future<PatientMedicalProfile> getPatientFullHistory({
    required String patientUserId,
    required String patientName,
  }) async {
    final emr = await patientEmr(patientUserId);
    return PatientMedicalProfile.fromEmrJson(
      patientId: patientUserId,
      patientName: patientName,
      emr: emr,
    );
  }

  Future<Map<String, dynamic>> safetyCheck({
    required String patientUserId,
    required String medicationName,
    String? dosage,
  }) async =>
      Map<String, dynamic>.from(
        await post('/clinical/safety-check', {
          'patientUserId': patientUserId,
          'medicationName': medicationName,
          if (dosage != null) 'dosage': dosage,
        }) as Map,
      );

  Future<void> postDiagnosis(Map<String, dynamic> body) async => post('/diagnoses', body);

  Future<void> postPrescription(Map<String, dynamic> body) async => post('/prescriptions', body);

  /// Atomic clinical session: diagnosis first, optional Rx + dispensing prescription.
  Future<bool> saveFullMedicalSession({
    required String patientUserId,
    required String patientName,
    required Map<String, dynamic> diagnosis,
    Map<String, dynamic>? prescription,
    String? appointmentId,
  }) async {
    await postDiagnosis({
      'patientUserId': patientUserId,
      'condition': diagnosis['condition'],
      'severity': diagnosis['severity'],
      'symptoms': diagnosis['symptoms'],
      'treatmentPlan': diagnosis['treatmentPlan'],
      if (appointmentId != null && appointmentId.isNotEmpty) 'appointmentId': appointmentId,
    });

    if (prescription == null) return true;

    final medicationName = prescription['medicationName']?.toString().trim() ?? '';
    if (medicationName.isEmpty) return true;

    final durationValue = prescription['durationValue']?.toString() ?? '';
    final durationUnit = prescription['durationUnit']?.toString() ?? 'Days';
    final duration = buildMedicationDurationString(durationValue, durationUnit);
    final dosage = prescription['dosage']?.toString().trim() ?? '';
    final frequency = prescription['frequency']?.toString().trim() ?? '';
    final extraInstructions = prescription['instructions']?.toString().trim() ?? '';
    final instructions = [
      if (dosage.isNotEmpty) 'Dosage: $dosage',
      if (frequency.isNotEmpty) 'Frequency: $frequency',
      if (duration.isNotEmpty) 'Duration: $duration',
      if (extraInstructions.isNotEmpty) extraInstructions,
    ].join(' · ');

    final rxResult = Map<String, dynamic>.from(
      await postPrescription({
        'patientUserId': patientUserId,
        'medicationName': medicationName,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
        'instructions': extraInstructions,
        if (appointmentId != null && appointmentId.isNotEmpty) 'appointmentId': appointmentId,
      }) as Map,
    );
    final isRxUpdate = rxResult['isUpdate'] == true;

    if (isRxUpdate) return true;

    final drugs = await searchDrugs(medicationName);
    Map<String, dynamic>? matchedDrug;
    final lowerName = medicationName.toLowerCase();
    for (final drug in drugs) {
      final name = drug['name']?.toString().toLowerCase() ?? '';
      if (name == lowerName || name.startsWith(lowerName)) {
        matchedDrug = drug;
        break;
      }
    }
    matchedDrug ??= drugs.isNotEmpty ? drugs.first : null;

    if (matchedDrug != null) {
      final drugId = matchedDrug['_id']?.toString() ?? matchedDrug['id']?.toString() ?? '';
      if (drugId.isNotEmpty) {
        final prescribedQuantity = computePrescribedQuantityFromDuration(durationValue, durationUnit);
        await postDispensingPrescription({
          'patientUserId': patientUserId,
          'patientName': patientName,
          'expiryDays': 30,
          if (appointmentId != null && appointmentId.isNotEmpty) 'appointmentId': appointmentId,
          'items': [
            {
              'drugId': drugId,
              'prescribedQuantity': prescribedQuantity,
              'duration': duration,
              'dosage': dosage,
              'frequency': frequency,
              'instructions': instructions,
            },
          ],
        });
      }
    }

    return true;
  }

  /// Controlled dispensing prescription (drug catalog + quantities).
  Future<Map<String, dynamic>> postDispensingPrescription(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await post('/dispensing-prescriptions', body) as Map);

  Future<List<Map<String, dynamic>>> searchDrugs(String query) async {
    final d = await get('/drugs', query: {'q': query.trim()});
    if (d is! List) return [];
    return [
      for (final entry in d)
        if (entry is Map) Map<String, dynamic>.from(entry),
    ];
  }

  Future<void> stopPrescription(String id) async => put('/prescriptions/$id/stop', {});

  Future<Map<String, dynamic>> postLabOrder({
    required String patientUserId,
    required String testName,
    required String testType,
    String? appointmentId,
  }) async {
    return Map<String, dynamic>.from(
      await post('/lab-requests', {
        'patientUserId': patientUserId,
        'patientId': patientUserId,
        'orderType': 'Laboratory',
        'testName': testName,
        'labTestName': testName,
        'testType': testType,
        'labType': testType,
        if (appointmentId != null && appointmentId.isNotEmpty) 'appointmentId': appointmentId,
      }) as Map,
    );
  }

  Future<Map<String, dynamic>> postRadiologyOrder({
    required String patientUserId,
    required String studyName,
    required String modality,
    String? appointmentId,
  }) async {
    return Map<String, dynamic>.from(
      await post('/radiology-requests', {
        'patientUserId': patientUserId,
        'patientId': patientUserId,
        'orderType': 'Radiology',
        'studyName': studyName,
        'modality': modality,
        'radiologyModality': modality,
        if (appointmentId != null && appointmentId.isNotEmpty) 'appointmentId': appointmentId,
      }) as Map,
    );
  }

  Future<void> postLabRequest(Map<String, dynamic> body) async => post('/lab-requests', body);

  Future<void> postRadiology(Map<String, dynamic> body) async => post('/radiology-requests', body);

  Future<void> notifyNurse({required String message, String? patientUserId}) async {
    await post('/nurse-notify', {
      'message': message,
      if (patientUserId != null) 'patientUserId': patientUserId,
    });
  }

  Future<List<dynamic>> appointments() async {
    final d = await get('/appointments');
    return d is List ? d : [];
  }

  Future<void> updateAppointmentStatus(String id, Map<String, dynamic> body) async {
    await put('/appointments/$id/status', body);
  }

  Future<void> postponeAppointment(String appointmentId) async {
    final r = await http
        .patch(
          Uri.parse('$rafeeqApiBase/api/appointments/$appointmentId/postpone'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<void> cancelAppointmentByDoctor({
    required String appointmentId,
    required String reason,
    String? notes,
  }) async {
    final r = await http
        .patch(
          Uri.parse('$rafeeqApiBase/api/appointments/$appointmentId/cancel-by-doctor'),
          headers: _headers,
          body: jsonEncode({
            'reason': reason,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<Map<String, dynamic>> postScheduleRequest(Map<String, dynamic> proposedSchedule) async =>
      Map<String, dynamic>.from(
        await post('/schedule-request', {
          'doctorId': doctorUserId,
          if (TenantState.instance.orgId.isNotEmpty) 'orgId': TenantState.instance.orgId,
          'proposedSchedule': proposedSchedule,
        }) as Map,
      );

  Future<Map<String, dynamic>> postLeaveRequest({
    required String type,
    required String startDate,
    required String endDate,
    String? reason,
  }) async =>
      Map<String, dynamic>.from(
        await post('/leave-request', {
          'doctorId': doctorUserId,
          if (TenantState.instance.orgId.isNotEmpty) 'orgId': TenantState.instance.orgId,
          'type': type,
          'startDate': startDate,
          'endDate': endDate,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          'status': 'pending',
        }) as Map,
      );
}
