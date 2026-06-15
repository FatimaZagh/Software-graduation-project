import 'package:flutter/material.dart';

import 'super_admin_api.dart';
import 'super_admin_theme.dart';
import 'widgets/staff_profile_sheet.dart';

class OrganizationDetailPage extends StatefulWidget {
  const OrganizationDetailPage({super.key, required this.orgId, required this.orgName});

  final String orgId;
  final String orgName;

  @override
  State<OrganizationDetailPage> createState() => _OrganizationDetailPageState();
}

class _OrganizationDetailPageState extends State<OrganizationDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _detail = {};
  Map<String, dynamic> _staff = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SuperAdminApi.getOrganizationDetail(widget.orgId),
        SuperAdminApi.getOrganizationStaff(widget.orgId),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = results[0];
        _staff = results[1];
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

  Future<void> _openStaff(Map<String, dynamic> member) async {
    final userId = member['id']?.toString() ?? '';
    if (userId.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StaffProfileSheet(orgId: widget.orgId, userId: userId, onSaved: _load),
    );
  }

  List<Map<String, dynamic>> _staffList(String key) {
    final raw = _staff[key];
    if (raw is! List) return [];
    return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
  }

  /// Nurses & Admin tab — strict role gate (excludes doctors, pharmacists, lab, etc.)
  List<Map<String, dynamic>> _nursesAndAdminOnly() {
    final combined = [..._staffList('nurses'), ..._staffList('administrative')];
    return combined.where((m) => isNurseOrAdminRole(m['role']?.toString())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final org = (_detail['organization'] as Map?)?.cast<String, dynamic>() ?? {};
    final counts = (_detail['staffCounts'] as Map?)?.cast<String, dynamic>() ?? {};

    return Scaffold(
      backgroundColor: kSuperAdminPremiumBg,
      appBar: AppBar(
        backgroundColor: kSuperAdminBlue,
        foregroundColor: Colors.white,
        title: Text(widget.orgName, style: superAdminTitle(16)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kSuperAdminGold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: superAdminPremiumValue(size: 13.5),
          unselectedLabelStyle: superAdminPremiumLabel(size: 13),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Doctors'),
            Tab(text: 'Nurses & Admin'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kSuperAdminGold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: superAdminPremiumValue(), textAlign: TextAlign.center),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(org: org, detail: _detail, counts: counts),
                    _StaffListTab(title: 'Doctors', members: _staffList('doctors'), onTap: _openStaff),
                    NursesAndAdminTab(members: _nursesAndAdminOnly(), onTap: _openStaff),
                  ],
                ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.org, required this.detail, required this.counts});

  final Map<String, dynamic> org;
  final Map<String, dynamic> detail;
  final Map<String, dynamic> counts;

  @override
  Widget build(BuildContext context) {
    final clinics = detail['clinics'] as List<dynamic>? ?? [];
    final departments = detail['departments'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        _InfoCard(
          title: 'Organization Meta',
          children: [
            _row('Name', org['name']?.toString() ?? '—'),
            _row('Contract', org['subscriptionType']?.toString() ?? 'Free'),
            _row('Status', org['status']?.toString() ?? '—'),
            _row('City', org['city']?.toString() ?? '—'),
            _row('Specialty', org['specialty']?.toString() ?? '—'),
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Staff Summary',
          children: [
            _row('Doctors', '${counts['doctors'] ?? 0}'),
            _row('Nurses', '${counts['nurses'] ?? 0}'),
            _row('Administrative', '${counts['administrative'] ?? 0}'),
            _row('Total', '${counts['total'] ?? 0}'),
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Departments (${departments.length})',
          children: departments.isEmpty
              ? [Text('No departments configured.', style: superAdminPremiumMuted())]
              : [
                  for (final d in departments)
                    if (d is Map) _row(d['name']?.toString() ?? 'Dept', d['description']?.toString() ?? '—'),
                ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Clinic Branches (${clinics.length})',
          children: clinics.isEmpty
              ? [Text('No clinic branches.', style: superAdminPremiumMuted())]
              : [
                  for (final c in clinics)
                    if (c is Map)
                      _row(
                        c['name']?.toString() ?? 'Clinic',
                        '${c['city'] ?? ''} ${c['address'] ?? ''}'.trim().isEmpty
                            ? '—'
                            : '${c['city'] ?? ''} ${c['address'] ?? ''}'.trim(),
                      ),
                ],
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(label, style: superAdminPremiumLabel()),
            ),
            Expanded(
              child: Text(
                value,
                style: superAdminPremiumValue(size: 13.5),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: superAdminPremiumCardDecoration(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: superAdminPremiumHeading()),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0x33D4AF37), height: 1),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Matches MongoDB role strings used for nurses and org admins only.
bool isNurseOrAdminRole(String? role) {
  final r = (role ?? '').trim().toLowerCase();
  return r == 'nurse' || r == 'organization admin' || r == 'admin';
}

/// Nurses & Admin tab — filters out pharmacists, doctors, lab techs, etc.
class NursesAndAdminTab extends StatelessWidget {
  const NursesAndAdminTab({super.key, required this.members, required this.onTap});

  final List<Map<String, dynamic>> members;
  final Future<void> Function(Map<String, dynamic>) onTap;

  static const Color _pageBg = Color(0xFF121212);
  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _gold = Color(0xFFD4AF37);

  BoxDecoration _goldCardDecoration() => BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold, width: 1.2),
      );

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return ColoredBox(
        color: _pageBg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No nurses or administrators on file.',
              style: superAdminPremiumMuted(size: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: _pageBg,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        itemCount: members.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final m = members[i];
          final initial =
              (m['name']?.toString().isNotEmpty == true ? m['name'].toString()[0] : '?').toUpperCase();

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onTap(m),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: _goldCardDecoration(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _gold.withValues(alpha: 0.18),
                      child: Text(
                        initial,
                        style: superAdminPremiumValue(size: 16).copyWith(color: _gold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['name']?.toString() ?? '—',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${m['role'] ?? ''} · ${m['status'] ?? ''}',
                            style: superAdminPremiumLabel(size: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_note_outlined, color: _gold, size: 22),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StaffListTab extends StatelessWidget {
  const _StaffListTab({required this.title, required this.members, required this.onTap});

  final String title;
  final List<Map<String, dynamic>> members;
  final Future<void> Function(Map<String, dynamic>) onTap;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No $title on file.', style: superAdminPremiumMuted(size: 14)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      itemCount: members.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final m = members[i];
        final initial = (m['name']?.toString().isNotEmpty == true ? m['name'].toString()[0] : '?').toUpperCase();

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(m),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: superAdminPremiumCardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: kSuperAdminGold.withValues(alpha: 0.18),
                    child: Text(
                      initial,
                      style: superAdminPremiumValue(size: 16).copyWith(color: kSuperAdminGold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['name']?.toString() ?? '—',
                          style: superAdminPremiumValue(size: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${m['role'] ?? ''} · ${m['status'] ?? ''}',
                          style: superAdminPremiumLabel(size: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_note_outlined, color: kSuperAdminGold, size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
