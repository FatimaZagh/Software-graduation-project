import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../login_screen.dart';
import '../../../tenant_state.dart';
import '../data/pharmacist_session.dart';
import 'pharmacist_theme.dart';

Future<void> _clearPharmacistSession() async {
  await PharmacistSession.instance.clear();
  TenantState.instance.clear();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('tenant.orgId');
  await prefs.remove('tenant.preferredClinicId');
}

/// Pops the dialog, clears auth, and resets navigation to login (no back into dashboard).
Future<void> _executePharmacistLogout(BuildContext dialogContext, BuildContext shellContext) async {
  Navigator.pop(dialogContext);

  await _clearPharmacistSession();

  if (!shellContext.mounted) return;

  try {
    GoRouter.of(shellContext).go('/login');
  } catch (_) {}

  if (!shellContext.mounted) return;

  await Navigator.of(shellContext, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

/// Clears pharmacist session and returns to the login gate.
Future<void> performPharmacistLogout(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: PharmacistTheme.card,
      title: const Text('Log out?', style: TextStyle(color: Colors.white)),
      content: Text('You will return to the login screen.', style: PharmacistTheme.bodyStyle()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _executePharmacistLogout(dialogContext, context),
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
}
