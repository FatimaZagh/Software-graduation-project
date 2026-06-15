import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n_extensions.dart';
import '../data/leave_api.dart';
import '../leave_navigation.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kEmerald = Color(0xFF0D1A17);
const Color _kEmeraldDeep = Color(0xFF0A1412);
const Color _kGlass = Color(0xE6101A18);
const Color _kFieldFill = Color(0xFF141A18);
const Color _kPendingYellow = Color(0xFFFFC857);

const _leaveTypes = [
  'Sick Leave',
  'Casual',
  'Annual Leave',
  'Emergency Leave',
  'Short Permission',
];

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({
    super.key,
    required this.userId,
    this.viewAsOrgAdmin = false,
  });

  final String userId;
  final bool viewAsOrgAdmin;

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  late final LeaveApi _api;
  final _reasonController = TextEditingController();
  final _dateFmt = DateFormat('MMM d, yyyy');
  final _submittedFmt = DateFormat('MMM d, yyyy · HH:mm');

  late Future<List<Map<String, dynamic>>> _historyFuture;
  String _leaveType = _leaveTypes.first;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _api = LeaveApi(userId: widget.userId);
    _historyFuture = _fetchHistory();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchHistory() {
    return _api.fetchHistory(asOrgAdmin: widget.viewAsOrgAdmin);
  }

  void _reloadHistory() {
    setState(() {
      _historyFuture = _fetchHistory();
    });
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _kGold,
              onPrimary: Colors.black,
              surface: _kFieldFill,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: _kEmerald),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (_startDate == null || _endDate == null) {
      _showSnack(context.isArabicLocale ? 'يرجى اختيار تاريخ البداية والنهاية' : 'Please select start and end dates');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _showSnack(context.isArabicLocale ? 'تاريخ النهاية يجب أن يكون بعد البداية' : 'End date must be on or after start date');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _api.submitRequest(
        leaveType: _leaveType,
        reason: reason,
        startDate: _startDate!,
        endDate: _endDate!,
      );
      if (!mounted) return;
      _reasonController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
        _submitting = false;
      });
      _reloadHistory();
      _showSuccessSnack();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack('$e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _kEmeraldDeep),
    );
  }

  void _showSuccessSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: _kGold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.isArabicLocale ? 'تم إرسال طلب الإجازة بنجاح' : 'Leave request submitted successfully',
                style: GoogleFonts.urbanist(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: _kEmerald,
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.urbanist(color: _kGold.withValues(alpha: 0.9)),
      filled: true,
      fillColor: _kFieldFill,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kGold.withValues(alpha: 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kGold, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isArabicLocale;
    return Scaffold(
      backgroundColor: _kEmeraldDeep,
      appBar: AppBar(
        backgroundColor: _kEmerald,
        foregroundColor: _kGoldLight,
        elevation: 0,
        title: Text(
          leaveRequestsNavLabel(context),
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: isAr ? 'تحديث' : 'Refresh',
            onPressed: _reloadHistory,
            icon: const Icon(Icons.refresh_rounded, color: _kGold),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kEmerald, _kEmeraldDeep, Color(0xFF050908)],
          ),
        ),
        child: RefreshIndicator(
          color: _kGold,
          backgroundColor: _kFieldFill,
          onRefresh: () async => _reloadHistory(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (!widget.viewAsOrgAdmin) ...[
                _sectionTitle(isAr ? 'تقديم طلب جديد' : 'Submit new request'),
                const SizedBox(height: 10),
                _submissionForm(isAr),
                const SizedBox(height: 24),
              ],
              _sectionTitle(
                widget.viewAsOrgAdmin
                    ? (isAr ? 'جميع طلبات الإجازة' : 'Organization leave requests')
                    : (isAr ? 'سجل طلباتي' : 'My request history'),
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator(color: _kGold)),
                    );
                  }
                  if (snapshot.hasError) {
                    return _errorPanel('${snapshot.error}', isAr);
                  }
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        isAr ? 'لا توجد طلبات إجازة بعد.' : 'No leave requests on record.',
                        style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 14),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final row in rows) _historyCard(row, isAr),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _submissionForm(bool isAr) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _leaveType,
            dropdownColor: _kFieldFill,
            decoration: _input(isAr ? 'نوع الإجازة' : 'Leave type'),
            items: [
              for (final t in _leaveTypes)
                DropdownMenuItem(
                  value: t,
                  child: Text(t, style: GoogleFonts.urbanist(color: Colors.white)),
                ),
            ],
            onChanged: _submitting ? null : (v) => setState(() => _leaveType = v ?? _leaveTypes.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonController,
            enabled: !_submitting,
            maxLines: 3,
            style: GoogleFonts.urbanist(color: Colors.white, height: 1.4),
            decoration: _input(isAr ? 'السبب' : 'Reason'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _dateButton(isAr ? 'تاريخ البداية' : 'Start date', _startDate, () => _pickDate(start: true))),
              const SizedBox(width: 10),
              Expanded(child: _dateButton(isAr ? 'تاريخ النهاية' : 'End date', _endDate, () => _pickDate(start: false))),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _kGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.send_rounded, size: 20),
            label: Text(
              isAr ? 'إرسال الطلب' : 'Submit request',
              style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime? value, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: _kGoldLight,
        side: BorderSide(color: _kGold.withValues(alpha: 0.55)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _submitting ? null : onTap,
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: Text(
        value == null ? label : _dateFmt.format(value),
        style: GoogleFonts.urbanist(fontSize: 12.5),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _errorPanel(String message, bool isAr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: GoogleFonts.urbanist(color: Colors.redAccent.shade100)),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _reloadHistory,
            child: Text(isAr ? 'إعادة المحاولة' : 'Retry', style: const TextStyle(color: _kGold)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 21, fontWeight: FontWeight.w700),
    );
  }

  Widget _historyCard(Map<String, dynamic> row, bool isAr) {
    final type = row['leaveType']?.toString() ?? row['type']?.toString() ?? 'Leave';
    final status = row['status']?.toString() ?? 'Pending';
    final reason = row['reason']?.toString().trim() ?? '';
    final rejection = row['rejectionReason']?.toString().trim() ?? '';
    final applicant = row['applicantName']?.toString().trim() ?? '';
    final submitted = _formatSubmittedAt(row);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: GoogleFonts.urbanist(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (widget.viewAsOrgAdmin && applicant.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          applicant,
                          style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                _statusBadge(status, isAr),
              ],
            ),
            const SizedBox(height: 10),
            _metaRow(
              icon: Icons.event_note_outlined,
              label: isAr ? 'الفترة' : 'Period',
              value: _formatRange(row),
            ),
            if (submitted.isNotEmpty) ...[
              const SizedBox(height: 6),
              _metaRow(
                icon: Icons.schedule_outlined,
                label: isAr ? 'تاريخ الطلب' : 'Requested',
                value: submitted,
              ),
            ],
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                isAr ? 'السبب' : 'Reason',
                style: GoogleFonts.urbanist(color: _kGold.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                reason,
                style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.82), fontSize: 14, height: 1.4),
              ),
            ],
            if (rejection.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${isAr ? 'سبب الرفض: ' : 'Rejection reason: '}$rejection',
                  style: GoogleFonts.urbanist(color: Colors.redAccent.shade100, fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaRow({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _kGold.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13, height: 1.35),
              children: [
                TextSpan(text: '$label · ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(
                  text: value,
                  style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String? status, bool isAr) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        _statusLabel(status, isAr),
        style: GoogleFonts.urbanist(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _statusLabel(String? status, bool isAr) {
    final s = (status ?? 'Pending').toLowerCase();
    if (isAr) {
      if (s.contains('approve')) return 'موافق عليه';
      if (s.contains('reject')) return 'مرفوض';
      return 'قيد المراجعة';
    }
    if (s.contains('approve')) return 'Approved';
    if (s.contains('reject')) return 'Rejected';
    return 'Pending';
  }

  Color _statusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.contains('approve')) return Colors.greenAccent;
    if (s.contains('reject')) return Colors.redAccent;
    return _kPendingYellow;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _formatRange(Map<String, dynamic> row) {
    final start = _parseDate(row['startDate'] ?? row['fromDate']);
    final end = _parseDate(row['endDate'] ?? row['toDate']);
    if (start == null && end == null) return '—';
    if (start != null && end != null) return '${_dateFmt.format(start)} → ${_dateFmt.format(end)}';
    final single = start ?? end;
    return single != null ? _dateFmt.format(single) : '—';
  }

  String _formatSubmittedAt(Map<String, dynamic> row) {
    final created = _parseDate(row['createdAt']);
    if (created == null) return '';
    return _submittedFmt.format(created.toLocal());
  }
}
