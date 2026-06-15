import 'package:flutter/material.dart';

import 'medication_payment_screen.dart';

export 'medication_payment_screen.dart'
    show MedicationPaymentResult, showMedicationPaymentSheet, MedicationPaymentScreen;

/// Backward-compatible alias for legacy imports.
typedef MockPaymentResult = MedicationPaymentResult;

Future<MedicationPaymentResult?> showPatientMockPaymentSheet(
  BuildContext context, {
  required String patientUserId,
  required String drugName,
  required int quantity,
}) {
  return showMedicationPaymentSheet(
    context,
    patientUserId: patientUserId,
    drugName: drugName,
    quantity: quantity,
  );
}
