import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../data/patient_medical_profile.dart';
import '../data/patient_portal_api.dart';
import 'patient_theme.dart';

const Color _kEhrBg = Color(0xFF121212);
const Color _kEhrCard = Color(0xFF1E1E1E);
const Color _kEhrMuted = Color(0xFFB3B3B3);

class PatientMedicalRecordsScreen extends StatefulWidget {
  const PatientMedicalRecordsScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<PatientMedicalRecordsScreen> createState() => _PatientMedicalRecordsScreenState();
}

class _PatientMedicalRecordsScreenState extends State<PatientMedicalRecordsScreen> {
  late Future<PatientMedicalProfile> _profileFuture;
  final _dateFmt = DateFormat('MMM d, yyyy · HH:mm');

  @override
  void initState() {
    super.initState();
    _profileFuture = PatientPortalApi.fetchPatientMedicalProfile(widget.patientUserId);
  }

  Future<void> _reload() async {
    setState(() {
      _profileFuture = PatientPortalApi.fetchPatientMedicalProfile(widget.patientUserId);
    });
    await _profileFuture;
  }

  String _formatVitals(Map<String, dynamic>? vitals, bool isArabic) {
    if (vitals == null || vitals.isEmpty) {
      return isArabic ? 'غير مسجلة' : 'Not recorded';
    }
    final parts = <String>[];
    final bp = vitals['bloodPressure']?.toString().trim();
    if (bp != null && bp.isNotEmpty) {
      parts.add(isArabic ? 'ضغط الدم: $bp mmHg' : 'BP: $bp mmHg');
    }
    final hr = vitals['heartRate'];
    if (hr != null) {
      parts.add(isArabic ? 'معدل النبض: $hr bpm' : 'Heart Rate: $hr bpm');
    }
    final temp = vitals['temperature'];
    if (temp != null) {
      parts.add(isArabic ? 'الحرارة: $temp °C' : 'Temperature: $temp °C');
    }
    return parts.isEmpty ? (isArabic ? 'غير مسجلة' : 'Not recorded') : parts.join(' · ');
  }

  String _prescribedPreview(List<String> meds, bool isArabic) {
    if (meds.isEmpty) {
      return isArabic ? 'لا توجد أدوية موصوفة' : 'No medications prescribed';
    }
    final prefix = isArabic ? 'وُصِف:' : 'Prescribed:';
    return '$prefix ${meds.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final retryLabel = isArabic ? 'إعادة المحاولة' : 'Retry';
    final doctorLabel = isArabic ? 'الطبيب' : 'Doctor';
    final clinicLabel = isArabic ? 'العيادة' : 'Clinic';
    final noneReported = l10n.medicalRecordNoneReported;
    final noneLabel = l10n.medicalRecordNone;

    return Scaffold(
      backgroundColor: _kEhrBg,
      appBar: AppBar(
        backgroundColor: _kEhrBg,
        foregroundColor: kPatientGold,
        elevation: 0,
        title: Text(l10n.medicalRecords, style: patientTitleStyle(18)),
        actions: [
          IconButton(
            tooltip: isArabic ? 'تحديث' : 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<PatientMedicalProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingState();
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              retryLabel: retryLabel,
              onRetry: _reload,
            );
          }

          final profile = snapshot.data!;
          return RefreshIndicator(
            color: kPatientGold,
            backgroundColor: _kEhrCard,
            onRefresh: _reload,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kEhrBg,
                      border: Border(
                        bottom: BorderSide(color: kPatientGold.withValues(alpha: 0.35)),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _BaselinePill(
                                icon: Icons.bloodtype_outlined,
                                label: l10n.medicalRecordBloodType,
                                value: profile.bloodType.isEmpty ? noneReported : profile.bloodType,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BaselinePill(
                                icon: Icons.warning_amber_rounded,
                                label: l10n.medicalRecordAllergies,
                                value: profile.allergies.isEmpty
                                    ? noneReported
                                    : profile.allergies.join(', '),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _ChronicConditionsCard(
                          label: l10n.medicalRecordChronicConditions,
                          conditions: profile.chronicConditions,
                          emptyLabel: noneLabel,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Row(
                      children: [
                        Icon(Icons.timeline_rounded, color: kPatientGold.withValues(alpha: 0.9), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.medicalRecordEncounterTimeline,
                          style: GoogleFonts.urbanist(
                            color: kPatientGold,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (profile.encounters.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyVisitsState(
                      title: l10n.medicalRecordNoVisits,
                      hint: l10n.medicalRecordNoVisitsHint,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverList.separated(
                      itemCount: profile.encounters.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final encounter = profile.encounters[index];
                        final diagnosis = encounter.diagnosis.isNotEmpty
                            ? encounter.diagnosis
                            : (isArabic ? 'لا يوجد تشخيص مسجل' : 'No diagnosis recorded');

                        return _EncounterCard(
                          diagnosisTitle: diagnosis,
                          visitDateText: encounter.visitDate != null
                              ? _dateFmt.format(encounter.visitDate!.toLocal())
                              : '—',
                          prescribedPreview: _prescribedPreview(encounter.prescribedMedications, isArabic),
                          doctorName: encounter.doctorName,
                          clinicName: encounter.clinicName,
                          chiefComplaint: encounter.chiefComplaint,
                          diagnosis: encounter.diagnosis,
                          vitalsText: _formatVitals(encounter.vitalSigns, isArabic),
                          notes: encounter.notes,
                          doctorLabel: doctorLabel,
                          clinicLabel: clinicLabel,
                          complaintLabel: l10n.medicalRecordChiefComplaint,
                          diagnosisLabel: l10n.medicalRecordDiagnosis,
                          vitalsLabel: l10n.medicalRecordVitals,
                          notesLabel: l10n.medicalRecordDoctorNotes,
                          notRecorded: isArabic ? 'غير مسجل' : 'Not recorded',
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(color: kPatientGold, strokeWidth: 2.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading medical records…',
            style: GoogleFonts.urbanist(color: _kEhrMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _BaselinePill extends StatelessWidget {
  const _BaselinePill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kEhrCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPatientGold, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPatientGold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.urbanist(
                    color: kPatientGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.urbanist(color: Colors.white, fontSize: 13.5, height: 1.3),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChronicConditionsCard extends StatelessWidget {
  const _ChronicConditionsCard({
    required this.label,
    required this.conditions,
    required this.emptyLabel,
  });

  final String label;
  final List<String> conditions;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kEhrCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPatientGold, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, color: kPatientGold, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.urbanist(
                  color: kPatientGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (conditions.isEmpty)
            Text(
              emptyLabel,
              style: GoogleFonts.urbanist(color: Colors.white, fontSize: 13.5, height: 1.3),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final condition in conditions)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kPatientGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kPatientGold.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      condition,
                      style: GoogleFonts.urbanist(
                        color: kPatientGoldLight,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EncounterCard extends StatelessWidget {
  const _EncounterCard({
    required this.diagnosisTitle,
    required this.visitDateText,
    required this.prescribedPreview,
    required this.doctorName,
    required this.clinicName,
    required this.chiefComplaint,
    required this.diagnosis,
    required this.vitalsText,
    required this.notes,
    required this.doctorLabel,
    required this.clinicLabel,
    required this.complaintLabel,
    required this.diagnosisLabel,
    required this.vitalsLabel,
    required this.notesLabel,
    required this.notRecorded,
  });

  final String diagnosisTitle;
  final String visitDateText;
  final String prescribedPreview;
  final String doctorName;
  final String clinicName;
  final String chiefComplaint;
  final String diagnosis;
  final String vitalsText;
  final String notes;
  final String doctorLabel;
  final String clinicLabel;
  final String complaintLabel;
  final String diagnosisLabel;
  final String vitalsLabel;
  final String notesLabel;
  final String notRecorded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kEhrCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPatientGold.withValues(alpha: 0.35)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: kPatientGold,
          collapsedIconColor: kPatientGold,
          title: Text(
            diagnosisTitle,
            style: GoogleFonts.urbanist(
              color: kPatientGoldLight,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visitDateText,
                  style: GoogleFonts.urbanist(
                    color: kPatientGold,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$doctorLabel · $doctorName',
                  style: GoogleFonts.urbanist(color: Colors.white, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '$clinicLabel · $clinicName',
                  style: GoogleFonts.urbanist(color: _kEhrMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Text(
                  prescribedPreview,
                  style: GoogleFonts.urbanist(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12.5,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(color: Color(0x33D4AF37), height: 20),
            _EncounterSection(
              label: complaintLabel,
              value: chiefComplaint.isEmpty ? notRecorded : chiefComplaint,
            ),
            const SizedBox(height: 12),
            _EncounterSection(
              label: diagnosisLabel,
              value: diagnosis.isEmpty ? notRecorded : diagnosis,
            ),
            const SizedBox(height: 12),
            _EncounterSection(label: vitalsLabel, value: vitalsText),
            const SizedBox(height: 12),
            _EncounterSection(
              label: notesLabel,
              value: notes.isEmpty ? notRecorded : notes,
            ),
          ],
        ),
      ),
    );
  }
}

class _EncounterSection extends StatelessWidget {
  const _EncounterSection({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.urbanist(
            color: kPatientGold,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.urbanist(color: Colors.white, fontSize: 13.5, height: 1.4),
        ),
      ],
    );
  }
}

class _EmptyVisitsState extends StatelessWidget {
  const _EmptyVisitsState({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _kEhrCard,
                shape: BoxShape.circle,
                border: Border.all(color: kPatientGold.withValues(alpha: 0.45)),
              ),
              child: Icon(Icons.medical_information_outlined, size: 44, color: kPatientGold.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(color: _kEhrMuted, fontSize: 13.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent.shade200, size: 42),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.urbanist(color: Colors.white70)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: kPatientGold, foregroundColor: _kEhrBg),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
