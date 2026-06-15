import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/responsive_layout.dart';
import '../../auth/presentation/auth_signup_theme.dart';
import '../models/doctor_billing_profile.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kGlass = Color(0xE6101A18);

class SessionBillingResult {
  const SessionBillingResult({required this.amount});
  final double amount;
}

/// Dark-and-gold session completion billing prompt.
Future<SessionBillingResult?> showSessionBillingDialog(
  BuildContext context, {
  required double defaultFee,
  required String patientName,
  String? displayedFeeLabel,
}) async {
  return showDialog<SessionBillingResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SessionBillingDialog(
      defaultFee: defaultFee,
      patientName: patientName,
      displayedFeeLabel: displayedFeeLabel,
    ),
  );
}

class _SessionBillingDialog extends StatefulWidget {
  const _SessionBillingDialog({
    required this.defaultFee,
    required this.patientName,
    this.displayedFeeLabel,
  });

  final double defaultFee;
  final String patientName;
  final String? displayedFeeLabel;

  @override
  State<_SessionBillingDialog> createState() => _SessionBillingDialogState();
}

class _SessionBillingDialogState extends State<_SessionBillingDialog> {
  bool _customMode = false;
  final _customController = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  double get _effectiveFee {
    final f = widget.defaultFee;
    return f > 0 ? f : DoctorBillingProfile.baselineFee;
  }

  String get _feeLabel {
    if (widget.displayedFeeLabel != null && widget.displayedFeeLabel!.isNotEmpty) {
      return widget.displayedFeeLabel!;
    }
    final f = _effectiveFee;
    return f.truncateToDouble() == f ? '${f.toInt()}' : f.toStringAsFixed(2);
  }

  double? _parsedCustom() {
    final v = double.tryParse(_customController.text.trim());
    if (v == null || v <= 0) return null;
    return v;
  }

  void _validateCustom(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _validationError = null;
        return;
      }
      final v = double.tryParse(value.trim());
      if (v == null || v <= 0) {
        _validationError = 'Enter a valid amount greater than zero';
      } else if (v > 50000) {
        _validationError = 'Amount exceeds maximum allowed (50,000 ILS)';
      } else {
        _validationError = null;
      }
    });
  }

  void _submitFull() {
    Navigator.pop(context, SessionBillingResult(amount: _effectiveFee));
  }

  void _submitCustom() {
    final v = _parsedCustom();
    if (v == null) {
      setState(() => _validationError = 'Enter a valid amount greater than zero');
      return;
    }
    Navigator.pop(context, SessionBillingResult(amount: v));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: RafeeqResponsive.of(context).dialogInsetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: RafeeqResponsive.of(context).dialogContentWidth(desktopMax: 440),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _kGlass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kGold.withValues(alpha: 0.65)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kGold.withValues(alpha: 0.45)),
                    ),
                    child: const Icon(Icons.check_circle_outline, color: _kGoldLight, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session complete',
                          style: GoogleFonts.urbanist(
                            color: _kGoldLight,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          widget.patientName,
                          style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Would you like to deduct the standard consultation fee ($_feeLabel ILS) or a custom override amount?',
                style: GoogleFonts.urbanist(color: Colors.white, height: 1.45, fontSize: 14),
              ),
              const SizedBox(height: 20),
              if (!_customMode) ...[
                AuthSignupTheme.primaryButton(
                  label: 'Confirm Base Fee ($_feeLabel ILS)',
                  onPressed: _submitFull,
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  style: AuthSignupTheme.outlineButtonStyle(),
                  onPressed: () => setState(() => _customMode = true),
                  child: Text(
                    'Custom Charge',
                    style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w700),
                  ),
                ),
              ] else ...[
                Text(
                  'Custom override (ILS)',
                  style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: AuthSignupTheme.fieldTextStyle(),
                  decoration: AuthSignupTheme.inputDecoration('Enter amount').copyWith(
                    errorText: _validationError,
                    suffixIcon: _parsedCustom() != null
                        ? Icon(Icons.check_circle, color: Colors.greenAccent.withValues(alpha: 0.9), size: 20)
                        : null,
                  ),
                  onChanged: _validateCustom,
                  onSubmitted: (_) => _submitCustom(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AuthSignupTheme.primaryButton(
                        label: 'Confirm Custom Charge',
                        onPressed: _validationError == null && _parsedCustom() != null ? _submitCustom : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: AuthSignupTheme.outlineButtonStyle(),
                      onPressed: () => setState(() {
                        _customMode = false;
                        _validationError = null;
                      }),
                      child: Text('Back', style: GoogleFonts.urbanist(color: Colors.white54)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Skip billing', style: GoogleFonts.urbanist(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
