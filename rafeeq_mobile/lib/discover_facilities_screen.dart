import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'l10n/l10n_extensions.dart';
import 'tenant_state.dart';
import 'features/patient_dashboard/presentation/patient_dashboard_shell.dart';
import 'widgets/rafeeq_language_toggle.dart';

class DiscoverFacilitiesScreen extends StatefulWidget {
  final String patientUserId;
  const DiscoverFacilitiesScreen({super.key, required this.patientUserId});

  @override
  State<DiscoverFacilitiesScreen> createState() => _DiscoverFacilitiesScreenState();
}

class _DiscoverFacilitiesScreenState extends State<DiscoverFacilitiesScreen> {
  bool _loading = true;
  String? _err;
  List<dynamic> _orgs = [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final r = await http.get(Uri.parse('$rafeeqApiBase/api/organizations')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception(r.body);
      final list = jsonDecode(r.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _orgs = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectOrg(Map<String, dynamic> org) async {
    final id = org['_id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      final r = await http.get(Uri.parse('$rafeeqApiBase/api/organizations/$id/theme')).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        TenantState.instance.setFromOrgPayload(id, jsonDecode(r.body));
      } else {
        TenantState.instance.setFromOrgPayload(id, org);
      }
    } catch (_) {
      TenantState.instance.setFromOrgPayload(id, org);
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PatientDashboardShell(patientUserId: widget.patientUserId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtered = _q.trim().isEmpty
        ? _orgs
        : _orgs.where((raw) {
            if (raw is! Map) return false;
            final name = (raw['name'] ?? '').toString().toLowerCase();
            final spec = (raw['specialty'] ?? '').toString().toLowerCase();
            final city = (raw['city'] ?? (raw['location'] is Map ? raw['location']['city'] ?? '' : ''))
                .toString()
                .toLowerCase();
            final addr = (raw['location'] is Map ? (raw['location']['address'] ?? '') : '').toString().toLowerCase();
            final t = _q.trim().toLowerCase();
            return name.contains(t) || spec.contains(t) || city.contains(t) || addr.contains(t);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.authDiscoverFacilities),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: const [RafeeqLanguageToggle()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_err!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        TextButton(onPressed: _load, child: Text(l10n.adminRetry)),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.authChooseFacility,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: l10n.authSearchFacilityHint,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _q = v),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(child: Text(l10n.authNoFacilitiesFound))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final raw = filtered[i];
                                  if (raw is! Map<String, dynamic>) return const SizedBox.shrink();
                                  final logo = (raw['logoUrl'] ?? '').toString().trim();
                                  final name = (raw['name'] ?? '').toString();
                                  final specialty = (raw['specialty'] ?? '').toString().trim();
                                  final loc = raw['location'] is Map ? raw['location'] as Map : const {};
                                  final city = (loc['city'] ?? '').toString().trim();
                                  final address = (loc['address'] ?? '').toString().trim();
                                  final locationLabel = [city, address].where((x) => x.isNotEmpty).join(' · ');

                                  return Card(
                                    child: ListTile(
                                      leading: logo.isNotEmpty
                                          ? CircleAvatar(
                                              backgroundColor: Colors.teal.shade50,
                                              child: ClipOval(
                                                child: Image.network(
                                                  logo,
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) =>
                                                      const Icon(Icons.local_hospital_outlined),
                                                ),
                                              ),
                                            )
                                          : const CircleAvatar(child: Icon(Icons.local_hospital_outlined)),
                                      title: Text(name),
                                      subtitle: Text(
                                        [
                                          if (specialty.isNotEmpty) specialty,
                                          if (locationLabel.isNotEmpty) locationLabel,
                                        ].join('\n'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _selectOrg(raw),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
