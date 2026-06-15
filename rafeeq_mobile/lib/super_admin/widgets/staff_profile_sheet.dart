import 'package:flutter/material.dart';

import '../super_admin_api.dart';
import '../super_admin_theme.dart';

class StaffProfileSheet extends StatefulWidget {
  const StaffProfileSheet({
    super.key,
    required this.orgId,
    required this.userId,
    required this.onSaved,
  });

  final String orgId;
  final String userId;
  final VoidCallback onSaved;

  @override
  State<StaffProfileSheet> createState() => _StaffProfileSheetState();
}

class _StaffProfileSheetState extends State<StaffProfileSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _data = {};

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _shiftStartCtrl = TextEditingController(text: '08:00');
  final _shiftEndCtrl = TextEditingController(text: '17:00');

  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _fieldFill = Color(0xFF2A2A2A);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _suspendAccent = Color(0xFFE57373);
  static const Color _activateAccent = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _specialtyCtrl.dispose();
    _shiftStartCtrl.dispose();
    _shiftEndCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SuperAdminApi.getStaffMember(widget.orgId, widget.userId);
      if (!mounted) return;
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      final shift = profile['shiftHours'] as Map<String, dynamic>? ?? {};
      _nameCtrl.text = data['name']?.toString() ?? '';
      _phoneCtrl.text = data['phoneNumber']?.toString() ?? '';
      _emailCtrl.text = data['email']?.toString() ?? '';
      _specialtyCtrl.text =
          profile['specialty']?.toString() ?? data['doctorProfile']?['specialization']?.toString() ?? '';
      _shiftStartCtrl.text = shift['start']?.toString() ?? '08:00';
      _shiftEndCtrl.text = shift['end']?.toString() ?? '17:00';
      setState(() {
        _data = data;
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SuperAdminApi.updateStaffMember(widget.orgId, widget.userId, {
        'name': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'specialty': _specialtyCtrl.text.trim(),
        'specialization': _specialtyCtrl.text.trim(),
        'shiftHours': {'start': _shiftStartCtrl.text.trim(), 'end': _shiftEndCtrl.text.trim()},
      });
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff profile updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setStatus(String status) async {
    try {
      await SuperAdminApi.updateStaffStatus(widget.orgId, widget.userId, status: status);
      if (!mounted) return;
      widget.onSaved();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    }
  }

  InputDecoration _inputDecoration(String label) {
    final idleBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _gold, width: 1.4),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: _gold, fontWeight: FontWeight.w600),
      filled: true,
      fillColor: _fieldFill,
      enabledBorder: idleBorder,
      focusedBorder: focusedBorder,
      border: idleBorder,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: const Icon(Icons.edit_outlined, color: _gold, size: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold, width: 1.0),
        ),
        child: _loading
            ? const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator(color: _gold)),
              )
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Staff Profile / ملف الموظف',
                          style: superAdminPremiumHeading(18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_data['role'] ?? ''} · ${_data['status'] ?? ''}',
                          style: superAdminPremiumLabel(size: 12.5),
                        ),
                        const SizedBox(height: 18),
                        _field('Name', _nameCtrl),
                        _field('Phone', _phoneCtrl),
                        _field('Email', _emailCtrl),
                        _field('Specialty / Department', _specialtyCtrl),
                        Row(
                          children: [
                            Expanded(child: _field('Shift start', _shiftStartCtrl)),
                            const SizedBox(width: 10),
                            Expanded(child: _field('Shift end', _shiftEndCtrl)),
                          ],
                        ),
                        if ((_data['identityNumber']?.toString() ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: Text(
                              'ID: ${_data['identityNumber']}',
                              style: superAdminPremiumMuted(size: 12),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Edit Staff Info / تعديل معلومات الموظف',
                          style: superAdminPremiumHeading(14),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_outlined, color: Colors.white),
                          label: Text(
                            _saving ? 'Saving… / جاري الحفظ…' : 'Save changes / حفظ التغييرات',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: kSuperAdminBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _setStatus('suspended'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _suspendAccent,
                                  side: BorderSide(color: _suspendAccent.withValues(alpha: 0.65)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text(
                                  'Suspend / إيقاف',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _setStatus('active'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _activateAccent,
                                  side: BorderSide(color: _activateAccent.withValues(alpha: 0.75)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text(
                                  'Activate / تفعيل',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: _gold,
          decoration: _inputDecoration(label),
        ),
      );
}
