import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n_extensions.dart';

/// Emergency numbers and one-tap dial (device dialer when supported).
class PatientEmergencyScreen extends StatelessWidget {
  final String patientUserId;

  const PatientEmergencyScreen({super.key, required this.patientUserId});

  Future<void> _dial(BuildContext context, String label, String rawNumber) async {
    final l10n = context.l10n;
    final cleaned = rawNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.patientDialerFailed(label))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.patientCallFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.patientEmergency),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.patientEmergencyHint,
            style: const TextStyle(color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 20),
          _row(
            context,
            title: l10n.patientEmergencyNational,
            number: '997',
            icon: Icons.local_hospital,
            color: Colors.red.shade700,
          ),
          _row(
            context,
            title: l10n.patientEmergencyCivilDefense,
            number: '998',
            icon: Icons.fire_truck,
            color: Colors.deepOrange,
          ),
          _row(
            context,
            title: l10n.patientEmergencyPolice,
            number: '999',
            icon: Icons.local_police,
            color: Colors.indigo.shade800,
          ),
          _row(
            context,
            title: l10n.patientEmergencyClinic24h,
            number: '+966112345678',
            icon: Icons.phone_in_talk,
            color: Colors.teal.shade700,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String title,
    required String number,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(number, style: const TextStyle(fontSize: 16)),
        trailing: FilledButton(
          onPressed: () => _dial(context, title, number),
          style: FilledButton.styleFrom(backgroundColor: color),
          child: Text(context.l10n.patientCallNow),
        ),
      ),
    );
  }
}
