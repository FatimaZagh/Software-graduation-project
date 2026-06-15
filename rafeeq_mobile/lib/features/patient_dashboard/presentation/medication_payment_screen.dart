import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/patient_portal_api.dart';
import 'patient_locale_text.dart';
import 'patient_theme.dart';

class MedicationPaymentResult {
  const MedicationPaymentResult({
    required this.cardholderName,
    required this.cardLastFour,
    this.paymentStatus = 'Paid',
    this.savedCardId,
    this.usedSavedCard = false,
  });

  final String cardholderName;
  final String cardLastFour;
  final String paymentStatus;
  final String? savedCardId;
  final bool usedSavedCard;
}

enum _PaymentChoice { saved, newCard }

/// Smart checkout: saved cards + CVV-only reuse, or full new-card form.
Future<MedicationPaymentResult?> showMedicationPaymentSheet(
  BuildContext context, {
  required String patientUserId,
  required String drugName,
  required int quantity,
  double? amount,
}) {
  return showModalBottomSheet<MedicationPaymentResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: kPatientSheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => MedicationPaymentScreen(
      patientUserId: patientUserId,
      drugName: drugName,
      quantity: quantity,
      amount: amount,
    ),
  );
}

class MedicationPaymentScreen extends StatefulWidget {
  const MedicationPaymentScreen({
    super.key,
    required this.patientUserId,
    required this.drugName,
    required this.quantity,
    this.amount,
  });

  final String patientUserId;
  final String drugName;
  final int quantity;
  final double? amount;

  @override
  State<MedicationPaymentScreen> createState() => _MedicationPaymentScreenState();
}

class _MedicationPaymentScreenState extends State<MedicationPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _savedCvvCtrl = TextEditingController();

  List<Map<String, dynamic>> _savedCards = [];
  String? _selectedSavedCardId;
  _PaymentChoice _choice = _PaymentChoice.newCard;

  bool _loadingCards = true;
  bool _processing = false;
  String? _formError;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _savedCvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCards() async {
    setState(() {
      _loadingCards = true;
      _loadError = null;
    });
    try {
      final cards = await PatientPortalApi.getSavedPaymentCards(widget.patientUserId);
      if (!mounted) return;
      setState(() {
        _savedCards = cards;
        _loadingCards = false;
        if (cards.isNotEmpty) {
          _choice = _PaymentChoice.saved;
          _selectedSavedCardId = cards.first['id']?.toString();
        } else {
          _choice = _PaymentChoice.newCard;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingCards = false;
        _choice = _PaymentChoice.newCard;
      });
    }
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  bool _validateExpiry(String value) {
    final match = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch(value.trim());
    if (match == null) return false;
    final year = int.parse(match.group(2)!);
    final now = DateTime.now();
    final currentYY = now.year % 100;
    return year >= currentYY;
  }

  Map<String, dynamic>? get _selectedSavedCard {
    if (_selectedSavedCardId == null) return null;
    for (final c in _savedCards) {
      if (c['id']?.toString() == _selectedSavedCardId) return c;
    }
    return null;
  }

  MedicationPaymentResult _resultFromRaw(Map<String, dynamic> raw, {required bool usedSavedCard}) {
    return MedicationPaymentResult(
      cardholderName: raw['cardholderName']?.toString() ?? '',
      cardLastFour: raw['cardLastFour']?.toString() ?? '',
      paymentStatus: raw['paymentStatus']?.toString() ?? 'Paid',
      savedCardId: raw['savedCardId']?.toString(),
      usedSavedCard: usedSavedCard,
    );
  }

  String get _checkoutMedicineLabel =>
      widget.quantity > 1 ? '${widget.drugName} × ${widget.quantity}' : widget.drugName;

  Future<void> _pay() async {
    final isArabic = patientIsArabic(context);
    setState(() => _formError = null);

    if (_choice == _PaymentChoice.saved) {
      final cvv = _savedCvvCtrl.text.trim();
      if (!RegExp(r'^\d{3,4}$').hasMatch(cvv)) {
        setState(() => _formError = isArabic ? 'رمز الأمان يجب أن يكون 3–4 أرقام' : 'CVV must be 3–4 digits');
        return;
      }
      final cardId = _selectedSavedCardId;
      if (cardId == null || cardId.isEmpty) {
        setState(() => _formError = isArabic ? 'اختر بطاقة محفوظة' : 'Select a saved card');
        return;
      }

      setState(() => _processing = true);
      try {
        final raw = await PatientPortalApi.checkoutPaymentRaw(
          patientUserId: widget.patientUserId,
          savedCardId: cardId,
          cvv: cvv,
          medicineName: _checkoutMedicineLabel,
          amount: widget.amount,
        );
        if (!mounted) return;
        if (raw['success'] != true && raw['paymentStatus'] != 'Paid') {
          setState(() => _formError = raw['message']?.toString() ?? 'Payment failed');
          return;
        }
        Navigator.pop(context, _resultFromRaw(raw, usedSavedCard: true));
      } catch (e) {
        if (!mounted) return;
        setState(() => _formError = e.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _processing = false);
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final cardDigits = _digitsOnly(_cardCtrl.text);
    if (cardDigits.length != 16) {
      setState(() => _formError = isArabic
          ? 'رقم البطاقة يجب أن يكون 16 رقماً'
          : 'Card number must be exactly 16 digits');
      return;
    }
    if (!RegExp(r'^\d{3,4}$').hasMatch(_cvvCtrl.text.trim())) {
      setState(() => _formError = isArabic ? 'رمز الأمان يجب أن يكون 3–4 أرقام' : 'CVV must be 3–4 digits');
      return;
    }
    if (!_validateExpiry(_expiryCtrl.text.trim())) {
      setState(() => _formError = isArabic ? 'تاريخ انتهاء غير صالح' : 'Invalid expiry date');
      return;
    }

    setState(() => _processing = true);
    try {
      final raw = await PatientPortalApi.checkoutPaymentRaw(
        patientUserId: widget.patientUserId,
        cardholderName: _nameCtrl.text.trim(),
        cardNumber: cardDigits,
        expirationDate: _expiryCtrl.text.trim(),
        cvv: _cvvCtrl.text.trim(),
        saveCard: true,
        medicineName: _checkoutMedicineLabel,
        amount: widget.amount,
      );
      if (!mounted) return;
      if (raw['success'] != true && raw['paymentStatus'] != 'Paid') {
        setState(() => _formError = raw['message']?.toString() ?? 'Payment failed');
        return;
      }
      Navigator.pop(context, _resultFromRaw(raw, usedSavedCard: false));
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Widget _savedCardSelector(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isArabic ? 'اختر طريقة الدفع' : 'Choose payment method',
          style: patientTitleStyle(14),
        ),
        const SizedBox(height: 10),
        ..._savedCards.map((card) {
          final id = card['id']?.toString() ?? '';
          final lastFour = card['cardLastFour']?.toString() ?? '????';
          final masked = card['maskedCardNumber']?.toString() ?? '**** **** **** $lastFour';
          final name = card['cardholderName']?.toString() ?? '';
          final expiry = card['expirationDate']?.toString() ?? '';
          final selected = _choice == _PaymentChoice.saved && _selectedSavedCardId == id;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: kPatientFieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? kPatientGold : Colors.white24,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: RadioListTile<String>(
              value: id,
              groupValue: _choice == _PaymentChoice.saved ? _selectedSavedCardId : null,
              activeColor: kPatientGold,
              onChanged: _processing
                  ? null
                  : (v) => setState(() {
                        _choice = _PaymentChoice.saved;
                        _selectedSavedCardId = v;
                      }),
              title: Text(
                isArabic ? 'البطاقة المحفوظة (تنتهي بـ $lastFour)' : 'Saved card (ending in $lastFour)',
                style: patientBodyStyle(size: 14).copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [name, masked, expiry.isNotEmpty ? 'Exp $expiry' : ''].where((s) => s.isNotEmpty).join(' · '),
                style: patientBodyStyle(color: Colors.white54, size: 12),
              ),
            ),
          );
        }),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: kPatientFieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _choice == _PaymentChoice.newCard ? kPatientGold : Colors.white24,
              width: _choice == _PaymentChoice.newCard ? 1.5 : 1,
            ),
          ),
          child: RadioListTile<_PaymentChoice>(
            value: _PaymentChoice.newCard,
            groupValue: _choice,
            activeColor: kPatientGold,
            onChanged: _processing ? null : (v) => setState(() => _choice = v!),
            title: Text(
              isArabic ? 'إضافة بطاقة جديدة' : 'Add a new card',
              style: patientBodyStyle(size: 14).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _savedCvvField(bool isArabic, TextAlign fieldAlign) {
    return TextFormField(
      controller: _savedCvvCtrl,
      enabled: !_processing,
      style: patientBodyStyle(),
      textAlign: fieldAlign,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.number,
      obscureText: true,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: patientInputDec(
        isArabic ? 'رمز الأمان (CVV)' : 'Security code (CVV)',
        hint: '123',
      ).copyWith(
        helperText: isArabic
            ? 'أدخل رمز CVV للتحقق — لا يُخزَّن على الخادم'
            : 'Enter CVV to verify — never stored on our servers',
        helperStyle: patientBodyStyle(color: Colors.white38, size: 11),
      ),
      validator: (v) {
        if (!RegExp(r'^\d{3,4}$').hasMatch((v ?? '').trim())) {
          return isArabic ? '3–4 أرقام' : '3–4 digits';
        }
        return null;
      },
    );
  }

  Widget _newCardForm(bool isArabic, TextAlign fieldAlign, TextDirection textDirection) {
    InputDecoration fieldDec(String label, {String? hint}) {
      return patientInputDec(label, hint: hint).copyWith(alignLabelWithHint: true);
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameCtrl,
            enabled: !_processing,
            style: patientBodyStyle(),
            textAlign: fieldAlign,
            textDirection: textDirection,
            decoration: fieldDec(
              isArabic ? 'اسم صاحب البطاقة' : 'Cardholder Name',
              hint: isArabic ? 'مثال: فاطمة أحمد' : 'e.g. Fatima Ahmad',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if ((v ?? '').trim().length < 2) {
                return isArabic ? 'أدخل اسم صاحب البطاقة' : 'Enter cardholder name';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _cardCtrl,
            enabled: !_processing,
            style: patientBodyStyle(),
            textAlign: fieldAlign,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              _CardNumberFormatter(),
            ],
            decoration: fieldDec(
              isArabic ? 'رقم البطاقة' : 'Card Number',
              hint: '0000 0000 0000 0000',
            ),
            validator: (v) {
              if (_digitsOnly(v ?? '').length != 16) {
                return isArabic ? '16 رقماً مطلوباً' : '16 digits required';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryCtrl,
                  enabled: !_processing,
                  style: patientBodyStyle(),
                  textAlign: fieldAlign,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    _ExpiryDateFormatter(),
                  ],
                  decoration: fieldDec(
                    isArabic ? 'تاريخ الانتهاء MM/YY' : 'Expiry MM/YY',
                    hint: 'MM/YY',
                  ),
                  validator: (v) {
                    if (!_validateExpiry((v ?? '').trim())) {
                      return isArabic ? 'MM/YY غير صالح' : 'Invalid MM/YY';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cvvCtrl,
                  enabled: !_processing,
                  style: patientBodyStyle(),
                  textAlign: fieldAlign,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: fieldDec(
                    isArabic ? 'رمز الأمان (CVV)' : 'CVV',
                    hint: '123',
                  ),
                  validator: (v) {
                    if (!RegExp(r'^\d{3,4}$').hasMatch((v ?? '').trim())) {
                      return isArabic ? '3–4 أرقام' : '3–4 digits';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'سيتم حفظ البطاقة للاستخدام المستقبلي بعد الدفع الناجح (بدون تخزين CVV).'
                : 'Card will be saved for future checkouts after successful payment (CVV never stored).',
            style: patientBodyStyle(color: Colors.white38, size: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = patientIsArabic(context);
    final fieldAlign = isArabic ? TextAlign.right : TextAlign.left;
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom + 20;
    final hasSavedCards = _savedCards.isNotEmpty;

    return Directionality(
      textDirection: textDirection,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPatientGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPatientGold.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.credit_card, color: kPatientGold, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isArabic ? 'إتمام عملية الدفع' : 'Complete Your Payment',
                      style: patientTitleStyle(17),
                      textAlign: fieldAlign,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.drugName} · ${isArabic ? 'الكمية' : 'Qty'}: ${widget.quantity}',
                style: patientBodyStyle(color: Colors.white70, size: 13),
                textAlign: fieldAlign,
              ),
              const SizedBox(height: 18),
              if (_loadingCards)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: kPatientGold)),
                )
              else ...[
                if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      isArabic ? 'تعذر تحميل البطاقات المحفوظة — استخدم بطاقة جديدة.' : 'Could not load saved cards — use a new card.',
                      style: patientBodyStyle(color: Colors.orangeAccent, size: 12),
                    ),
                  ),
                if (hasSavedCards) ...[
                  _savedCardSelector(isArabic),
                  const SizedBox(height: 14),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kPatientFieldFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kPatientGold.withValues(alpha: 0.35)),
                  ),
                  child: _choice == _PaymentChoice.saved && hasSavedCards
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_selectedSavedCard != null)
                              Text(
                                isArabic
                                    ? 'الدفع بالبطاقة ${_selectedSavedCard!['maskedCardNumber'] ?? ''}'
                                    : 'Pay with ${_selectedSavedCard!['maskedCardNumber'] ?? 'saved card'}',
                                style: patientBodyStyle(color: Colors.white70, size: 13),
                              ),
                            const SizedBox(height: 12),
                            _savedCvvField(isArabic, fieldAlign),
                          ],
                        )
                      : _newCardForm(isArabic, fieldAlign, textDirection),
                ),
              ],
              if (_formError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _formError!,
                  style: patientBodyStyle(color: Colors.redAccent, size: 13),
                  textAlign: fieldAlign,
                ),
              ],
              const SizedBox(height: 18),
              if (_processing)
                Column(
                  children: [
                    const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: kPatientGold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isArabic ? 'جاري المعالجة…' : 'Processing…',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(color: kPatientGoldLight, fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              else if (!_loadingCards)
                FilledButton(
                  onPressed: _pay,
                  style: FilledButton.styleFrom(
                    backgroundColor: kPatientGoldDeep,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isArabic ? 'تأكيد الدفع' : 'Confirm Payment',
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                isArabic
                    ? 'دفع تجريبي آمن — لا يُخزَّن رمز CVV (متوافق مع PCI-DSS)'
                    : 'Secure mock checkout — CVV never stored (PCI-DSS compliant)',
                textAlign: TextAlign.center,
                style: patientBodyStyle(color: Colors.white38, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2) buf.write('/');
      buf.write(limited[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
