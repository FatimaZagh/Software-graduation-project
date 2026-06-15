import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_extensions.dart';
import '../super_admin_api.dart';
import '../super_admin_theme.dart';

class PendingApplicationsTab extends StatefulWidget {
  const PendingApplicationsTab({super.key});

  @override
  State<PendingApplicationsTab> createState() => _PendingApplicationsTabState();
}

class _PendingApplicationsTabState extends State<PendingApplicationsTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _payload = {};
  final Set<String> _acting = {};
  final _dateFmt = DateFormat('MMM d, yyyy');

  static const Color _pageBg = Color(0xFF121212);
  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _emerald = Color(0xFF004D40);
  static const Color _rejectRed = Color(0xFFB71C1C);
  static const Color _rejectRedSoft = Color(0xFFEF9A9A);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await SuperAdminApi.getPendingApplications();
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _payload[key];
    if (raw is! List) return [];
    return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
  }

  void _showRejectSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _rejectRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _acceptFacility(String orgId) async {
    setState(() => _acting.add(orgId));
    try {
      await SuperAdminApi.approveOrganization(orgId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facility approved successfully.')),
      );
      _removeFromList('pendingOrganizations', orgId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _acting.remove(orgId));
    }
  }

  Future<void> _rejectFacility(String orgId) async {
    setState(() => _acting.add(orgId));
    try {
      await SuperAdminApi.rejectOrganization(orgId);
      if (!mounted) return;
      _showRejectSnackBar('Facility request declined');
      _removeFromList('pendingOrganizations', orgId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _acting.remove(orgId));
    }
  }

  Future<void> _acceptRegistration(String id, {required String listKey}) async {
    setState(() => _acting.add(id));
    try {
      if (listKey == 'pendingStaff') {
        await SuperAdminApi.approvePendingStaff(id);
      } else {
        await SuperAdminApi.approvePendingRegistration(id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            listKey == 'pendingStaff'
                ? 'Staff account approved successfully.'
                : 'Registration approved successfully.',
          ),
        ),
      );
      _removeFromList(listKey, id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _acting.remove(id));
    }
  }

  Future<void> _rejectRegistration(String id, {required String listKey}) async {
    setState(() => _acting.add(id));
    try {
      if (listKey == 'pendingStaff') {
        await SuperAdminApi.rejectPendingStaff(id);
      } else {
        await SuperAdminApi.rejectPendingRegistration(id);
      }
      if (!mounted) return;
      _showRejectSnackBar(
        listKey == 'pendingStaff'
            ? 'Staff request declined'
            : 'Registration request declined',
      );
      _removeFromList(listKey, id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _acting.remove(id));
    }
  }

  String _itemId(Map<String, dynamic> item) =>
      (item['id'] ?? item['_id'] ?? item['orgId'])?.toString() ?? '';

  void _removeFromList(String key, String id) {
    if (id.isEmpty) return;
    final updated = _list(key).where((item) => _itemId(item) != id).toList();
    setState(() {
      _payload = Map<String, dynamic>.from(_payload)..[key] = updated;
    });
  }

  Widget _actionButtonRow({
    required VoidCallback? onAccept,
    required VoidCallback? onReject,
    bool busy = false,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton(
          onPressed: busy ? null : onAccept,
          style: FilledButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: _emerald,
            disabledBackgroundColor: _gold.withValues(alpha: 0.35),
            disabledForegroundColor: _emerald.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            minimumSize: const Size(0, 38),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            elevation: 0,
          ),
          child: Text(busy ? '…' : 'Accept'),
        ),
        OutlinedButton(
          onPressed: busy ? null : onReject,
          style: OutlinedButton.styleFrom(
            foregroundColor: _rejectRedSoft,
            backgroundColor: const Color(0xFF2A1212),
            disabledForegroundColor: _rejectRedSoft.withValues(alpha: 0.45),
            side: const BorderSide(color: _rejectRed, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            minimumSize: const Size(0, 38),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }

  BoxDecoration _goldCardDecoration() => BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold, width: 1.2),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pendingOrgs = _list('pendingOrganizations');
    final regs = _list('pendingRegistrations');
    final staff = _list('pendingStaff');
    final totalPending = pendingOrgs.length + regs.length + staff.length;

    return ColoredBox(
      color: _pageBg,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _error != null && pendingOrgs.isEmpty && regs.isEmpty && staff.isEmpty
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
              : RefreshIndicator(
                  color: _gold,
                  backgroundColor: _cardBg,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      Text(l10n.superAdminPendingQueueTitle(totalPending), style: superAdminPremiumHeading(17)),
                      const SizedBox(height: 18),
                      _sectionTitle(l10n.superAdminFacilityRegistrations(pendingOrgs.length)),
                      if (pendingOrgs.isEmpty)
                        Text(l10n.superAdminNoPendingFacilities, style: superAdminPremiumMuted())
                      else
                        ...pendingOrgs.map(_facilityCard),
                      const SizedBox(height: 18),
                      _sectionTitle(l10n.superAdminStaffRegistrationRequests(regs.length)),
                      if (regs.isEmpty)
                        Text(l10n.superAdminNoPendingStaffRequests, style: superAdminPremiumMuted())
                      else
                        ...regs.map((r) => _queueTile(r, listKey: 'pendingRegistrations')),
                      const SizedBox(height: 18),
                      _sectionTitle(l10n.superAdminPendingStaffAccountsTitle(staff.length)),
                      if (staff.isEmpty)
                        Text(l10n.superAdminNoPendingStaffAccounts, style: superAdminPremiumMuted())
                      else
                        ...staff.map((r) => _queueTile(r, listKey: 'pendingStaff')),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: superAdminPremiumHeading(14)),
      );

  Widget _facilityCard(Map<String, dynamic> o) {
    final id = _itemId(o);
    final busy = _acting.contains(id);
    final title = o['name']?.toString() ?? 'Unnamed';
    final city = o['city']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _goldCardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: superAdminPremiumLabel(size: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _actionButtonRow(
            busy: busy,
            onAccept: id.isEmpty ? null : () => _acceptFacility(id),
            onReject: id.isEmpty ? null : () => _rejectFacility(id),
          ),
        ],
      ),
    );
  }

  Widget _queueTile(Map<String, dynamic> r, {required String listKey}) {
    final id = _itemId(r);
    final busy = _acting.contains(id);
    final date = DateTime.tryParse(r['submittedAt']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _goldCardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['name']?.toString() ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${r['role'] ?? ''} · ${r['orgName'] ?? '—'}${date != null ? ' · ${_dateFmt.format(date)}' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: superAdminPremiumLabel(size: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _actionButtonRow(
            busy: busy,
            onAccept: id.isEmpty ? null : () => _acceptRegistration(id, listKey: listKey),
            onReject: id.isEmpty ? null : () => _rejectRegistration(id, listKey: listKey),
          ),
        ],
      ),
    );
  }
}
