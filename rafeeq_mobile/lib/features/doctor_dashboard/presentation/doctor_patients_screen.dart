import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/doctor_workspace_api.dart';
import 'doctor_chat_room_screen.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kGlass = Color(0xE6101A18);
const Color _kWorkspaceBlack = Color(0xFF0B0B0C);
const Color _kFieldFill = Color(0xFF1A1A18);

/// Searchable directory of patients associated with the logged-in doctor.
class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key, required this.api});

  final DoctorWorkspaceApi api;

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load([String? query]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.api.patients(q: query?.trim());
      if (!mounted) return;
      setState(() {
        _patients = [
          for (final item in raw)
            if (item is Map) Map<String, dynamic>.from(item),
        ];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _openChat(Map<String, dynamic> patient) {
    final patientUserId = patient['patientUserId']?.toString() ?? patient['_id']?.toString() ?? '';
    if (patientUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient ID missing — cannot open chat.')),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DoctorChatRoomScreen(
          api: widget.api,
          patientUserId: patientUserId,
          patientName: patient['name']?.toString() ?? 'Patient',
        ),
      ),
    );
  }

  String _subtitle(Map<String, dynamic> p) {
    final parts = <String>[];
    final age = p['age'];
    if (age is num && age > 0) parts.add('${age.toInt()} yrs');
    final gender = p['gender']?.toString().trim();
    if (gender != null && gender.isNotEmpty) parts.add(gender);
    if (parts.isNotEmpty) return parts.join(' · ');
    final email = p['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    return p['phone']?.toString() ?? '';
  }

  Widget _avatar(Map<String, dynamic> p) {
    final name = p['name']?.toString() ?? 'P';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final imageUrl = p['profileImageUrl']?.toString().trim() ?? '';

    ImageProvider? image;
    if (imageUrl.startsWith('data:image')) {
      try {
        final b64 = imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
        image = MemoryImage(base64Decode(b64));
      } catch (_) {}
    } else if (imageUrl.startsWith('http')) {
      image = NetworkImage(imageUrl);
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: _kGold.withValues(alpha: 0.18),
      backgroundImage: image,
      child: image == null
          ? Text(initial, style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w800, fontSize: 18))
          : null,
    );
  }

  Widget _patientCard(Map<String, dynamic> p) {
    final name = p['name']?.toString() ?? 'Patient';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openChat(p),
        child: Ink(
          decoration: BoxDecoration(
            color: _kGlass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kGold.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _avatar(p),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.urbanist(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle(p),
                        style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Message',
                  onPressed: () => _openChat(p),
                  style: IconButton.styleFrom(
                    backgroundColor: _kGold.withValues(alpha: 0.15),
                    foregroundColor: _kGoldLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _kGold.withValues(alpha: 0.55)),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kWorkspaceBlack,
      appBar: AppBar(
        backgroundColor: _kWorkspaceBlack,
        foregroundColor: _kGold,
        title: Text('My Patients', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(_searchCtrl.text),
            icon: const Icon(Icons.refresh, color: _kGoldLight),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Search patients by name…',
              hintStyle: WidgetStatePropertyAll(GoogleFonts.urbanist(color: Colors.white38, fontSize: 14)),
              textStyle: WidgetStatePropertyAll(GoogleFonts.urbanist(color: Colors.white, fontSize: 14)),
              backgroundColor: WidgetStatePropertyAll(_kFieldFill),
              elevation: const WidgetStatePropertyAll(0),
              leading: const Icon(Icons.search, color: _kGoldLight, size: 22),
              trailing: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      _load();
                    },
                  ),
              ],
              onSubmitted: _load,
              onChanged: (value) {
                setState(() {});
                if (value.trim().isEmpty) _load();
              },
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: _kGold.withValues(alpha: 0.45)),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kGold))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => _load(_searchCtrl.text),
                                style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: _kGold,
                        onRefresh: () => _load(_searchCtrl.text),
                        child: _patients.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 32),
                                    child: Column(
                                      children: [
                                        Icon(Icons.people_outline, size: 48, color: _kGold.withValues(alpha: 0.5)),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No patients found',
                                          style: GoogleFonts.urbanist(
                                            color: _kGoldLight,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Patients linked to your practice through appointments and registrations will appear here.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.urbanist(color: Colors.white54, height: 1.45),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _patients.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, index) => _patientCard(_patients[index]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
