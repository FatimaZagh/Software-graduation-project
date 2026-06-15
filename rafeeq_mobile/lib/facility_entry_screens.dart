import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

import 'api_config.dart';
import 'login_screen.dart';
import 'features/auth/presentation/role_selection_screen.dart';
import 'tenant_state.dart';
import 'widgets/rafeeq_back_home_button.dart';

const Color _facilityGold = Color(0xFFD4AF37);

/// Deep link: branch / clinic under a tenant (Mongo `Clinic._id`).
class ClinicFacilityEntryScreen extends StatefulWidget {
  final String clinicId;

  const ClinicFacilityEntryScreen({super.key, required this.clinicId});

  @override
  State<ClinicFacilityEntryScreen> createState() => _ClinicFacilityEntryScreenState();
}

class _ClinicFacilityEntryScreenState extends State<ClinicFacilityEntryScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _payload;

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
      final r = await http
          .get(Uri.parse('$rafeeqApiBase/api/clinics/${widget.clinicId}/profile'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) {
        throw Exception(r.body);
      }
      final map = jsonDecode(r.body);
      if (map is! Map) throw Exception('Invalid response');
      if (!mounted) return;
      setState(() {
        _payload = Map<String, dynamic>.from(map);
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

  Future<void> _applyTenantAndNavigate(Widget destination) async {
    final p = _payload;
    if (p == null) return;
    final org = p['organization'];
    if (org is! Map) return;
    final orgMap = Map<String, dynamic>.from(org);
    final orgOid = orgMap['_id']?.toString() ?? '';
    if (orgOid.isEmpty) return;

    final clinic = p['clinic'];
    final clinicId =
        clinic is Map ? clinic['_id']?.toString() ?? widget.clinicId : widget.clinicId;

    TenantState.instance.setFromOrgPayload(orgOid, {
      ...orgMap,
      'logoUrl': p['logoUrl'] ?? orgMap['logoUrl'] ?? '',
    });
    await TenantState.instance.setPreferredClinicId(clinicId);

    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => destination));
  }

  Widget _heroLogo(String logoUrl, String fallbackLetter) {
    final u = logoUrl.trim();
    if (u.isEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundColor: Colors.teal.shade800,
        child: Text(
          fallbackLetter.isEmpty ? 'R' : fallbackLetter.substring(0, 1).toUpperCase(),
          style: const TextStyle(fontSize: 36, color: Colors.white),
        ),
      );
    }
    Uri? uri;
    try {
      uri = Uri.parse(u);
      if (!uri.hasScheme) uri = null;
    } catch (_) {
      uri = null;
    }
    return CircleAvatar(
      radius: 48,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: uri == null
            ? Icon(Icons.local_hospital_rounded, size: 48, color: Colors.teal.shade800)
            : Image.network(
                uri.toString(),
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.local_hospital_rounded, size: 48, color: Colors.teal.shade800),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: rafeeqBackHomeAppBarLeading(context),
        title: const Text('Facility'),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF06332E),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final p = _payload!;
    final clinic = p['clinic'];
    final org = p['organization'];
    final name = clinic is Map ? (clinic['name'] ?? 'Clinic').toString() : 'Clinic';
    final displayLoc = (p['displayLocation'] ?? '').toString();
    final orgName =
        org is Map ? (org['name'] ?? '').toString() : '';
    final logo = (p['logoUrl'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _heroLogo(logo, name)),
          const SizedBox(height: 24),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF06332E),
            ),
          ),
          if (orgName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              orgName,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 15),
            ),
          ],
          if (displayLoc.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    displayLoc,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Sign in or create an account to use this branch.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF06332E),
              foregroundColor: _facilityGold,
            ),
            onPressed: () => _applyTenantAndNavigate(const LoginScreen()),
            child: Text('Continue to Login', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.teal.shade800),
            ),
            onPressed: () => _applyTenantAndNavigate(const RoleSelectionScreen()),
            child: Text('Continue to Sign up', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Landing fallback when tenant has clinics only at org level (no branches yet).
class OrgFacilityEntryScreen extends StatefulWidget {
  final String orgId;

  const OrgFacilityEntryScreen({super.key, required this.orgId});

  @override
  State<OrgFacilityEntryScreen> createState() => _OrgFacilityEntryScreenState();
}

class _OrgFacilityEntryScreenState extends State<OrgFacilityEntryScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _org;

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
      final r = await http
          .get(Uri.parse('$rafeeqApiBase/api/organizations/${widget.orgId}/theme'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception(r.body);
      final map = jsonDecode(r.body);
      if (map is! Map) throw Exception('Invalid response');
      if (!mounted) return;
      setState(() {
        _org = Map<String, dynamic>.from(map);
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

  Future<void> _continue(Widget destination) async {
    final o = _org;
    if (o == null) return;
    final oid = o['_id']?.toString() ?? widget.orgId;
    TenantState.instance.setFromOrgPayload(oid, o);
    await TenantState.instance.setPreferredClinicId(null);

    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: rafeeqBackHomeAppBarLeading(context),
        title: const Text('Facility'),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF06332E),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final o = _org!;
    final name = (o['name'] ?? 'Organization').toString();
    final logo = (o['logoUrl'] ?? '').toString();
    final locLine = [
      (o['address'] ?? '').toString().trim(),
      (o['city'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' • ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.teal.shade800,
              child: logo.trim().isEmpty
                  ? const Icon(Icons.business_rounded, size: 48, color: _facilityGold)
                  : ClipOval(
                      child: Image.network(
                        logo,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.business_rounded, color: _facilityGold, size: 44),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF06332E),
            ),
          ),
          if (locLine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                locLine,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          const SizedBox(height: 32),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF06332E),
              foregroundColor: _facilityGold,
            ),
            onPressed: () => _continue(const LoginScreen()),
            child: Text('Continue to Login', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.teal.shade800),
            ),
            onPressed: () => _continue(const RoleSelectionScreen()),
            child: Text('Continue to Sign up', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
