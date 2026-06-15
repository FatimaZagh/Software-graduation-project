import 'package:flutter/material.dart';

import '../features/diagnostic/presentation/technician_diagnostic_shell.dart';
import '../l10n/l10n_extensions.dart';
import '../widgets/rafeeq_language_toggle.dart';
import '../features/leave/leave_navigation.dart';

class NurseDashboard extends StatelessWidget {
  const NurseDashboard({super.key, required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _RoleScaffold(
      title: l10n.authNurseDashboard,
      subtitle: l10n.authNurseDashboardSubtitle,
      userId: userId,
    );
  }
}

class LabTechnicianDashboard extends StatelessWidget {
  const LabTechnicianDashboard({super.key, required this.userId, this.userName});
  final String userId;
  final String? userName;
  @override
  Widget build(BuildContext context) => TechnicianDiagnosticShell(
        userId: userId,
        userName: userName,
        kind: TechnicianDiagnosticKind.lab,
      );
}

class RadiologistDashboard extends StatelessWidget {
  const RadiologistDashboard({super.key, required this.userId, this.userName});
  final String userId;
  final String? userName;
  @override
  Widget build(BuildContext context) => TechnicianDiagnosticShell(
        userId: userId,
        userName: userName,
        kind: TechnicianDiagnosticKind.radiology,
      );
}

class PharmacistDashboard extends StatelessWidget {
  const PharmacistDashboard({super.key, required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _RoleScaffold(
      title: l10n.authPharmacistDashboard,
      subtitle: l10n.authPharmacistDashboardSubtitle,
      userId: userId,
    );
  }
}

class InternTraineeDashboard extends StatelessWidget {
  const InternTraineeDashboard({super.key, required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _RoleScaffold(
      title: l10n.authInternDashboard,
      subtitle: l10n.authInternDashboardSubtitle,
      userId: userId,
    );
  }
}

class StaffOperationsDashboard extends StatelessWidget {
  const StaffOperationsDashboard({super.key, required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _RoleScaffold(
      title: l10n.authStaffDashboard,
      subtitle: l10n.authStaffDashboardSubtitle,
      userId: userId,
    );
  }
}

class _RoleScaffold extends StatelessWidget {
  const _RoleScaffold({
    required this.title,
    required this.subtitle,
    required this.userId,
  });

  final String title;
  final String subtitle;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: leaveRequestsNavLabel(context),
            icon: const Icon(Icons.time_to_leave_outlined),
            onPressed: () => openLeaveRequestScreen(context, userId: userId),
          ),
          const RafeeqLanguageToggle(),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(subtitle),
                    const SizedBox(height: 12),
                    Text(l10n.authUserId(userId), style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
