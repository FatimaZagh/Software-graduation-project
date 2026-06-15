import 'package:flutter/material.dart';

import 'package:rafeeq_mobile/features/leave/presentation/leave_request_screen.dart';
/// Sidebar / drawer label for leave requests (EN + AR).
String leaveRequestsNavLabel(BuildContext context) {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  return isAr ? 'طلبات الإجازات والمغادرات' : 'Leave Requests';
}

void openLeaveRequestScreen(
  BuildContext context, {
  required String userId,
  bool viewAsOrgAdmin = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LeaveRequestScreen(
        userId: userId,
        viewAsOrgAdmin: viewAsOrgAdmin,
      ),
    ),
  );
}
