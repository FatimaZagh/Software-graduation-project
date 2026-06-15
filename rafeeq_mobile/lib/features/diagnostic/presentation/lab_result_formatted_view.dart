import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/presentation/auth_signup_theme.dart';
import '../../nurse_dashboard/presentation/lab_result_dynamic_form.dart';

/// Parses [resultAnalysis] JSON and renders a structured lab report (doctor or patient).
class LabResultFormattedView extends StatelessWidget {
  const LabResultFormattedView({
    super.key,
    required this.resultAnalysis,
    this.fallbackTestType,
    this.accentColor,
    this.accentLightColor,
  });

  final String? resultAnalysis;
  final String? fallbackTestType;
  final Color? accentColor;
  final Color? accentLightColor;

  Color get _gold => accentColor ?? AuthSignupColors.gold;
  Color get _goldLight => accentLightColor ?? AuthSignupColors.goldLight;

  static Map<String, dynamic>? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final parsed = tryParse(resultAnalysis);
    if (parsed == null) {
      final text = resultAnalysis?.trim() ?? '';
      if (text.isEmpty) {
        return Text(
          'No analysis provided',
          style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
        );
      }
      return Text(
        text,
        style: GoogleFonts.urbanist(color: Colors.white70, height: 1.45, fontSize: 13),
      );
    }
    if (fallbackTestType != null && (parsed['testType'] == null || parsed['testType'].toString().isEmpty)) {
      parsed['testType'] = fallbackTestType;
    }
    return _buildFormattedResultView(parsed);
  }

  Widget _buildFormattedResultView(Map<String, dynamic> data) {
    final testType = normalizeLabTestType(data['testType']?.toString() ?? fallbackTestType ?? 'Blood');
    switch (testType) {
      case 'Blood':
        return _bloodView(data);
      case 'Urine':
        return _urineView(data);
      case 'Culture':
        return _cultureView(data);
      case 'Biochemistry':
        return _biochemistryView(data);
      default:
        return _plainMapView(data);
    }
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.poppins(
            color: _gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      );

  Map<String, dynamic>? _nestedMap(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  List<Map<String, dynamic>> _nestedList(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is! List) return [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _str(dynamic v) => v == null ? '' : v.toString().trim();

  Widget _kvRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: GoogleFonts.urbanist(color: _gold, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.88), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: Colors.white.withValues(alpha: 0.08), height: 1);

  Widget _mapSection(String title, Map<String, dynamic>? section, Map<String, String> labels) {
    if (section == null || section.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    if (labels.isEmpty) {
      for (final e in section.entries) {
        final val = _str(e.value);
        if (val.isNotEmpty) rows.add(_kvRow(e.key, val));
      }
    } else {
      for (final e in labels.entries) {
        final val = _str(section[e.key]);
        if (val.isNotEmpty) rows.add(_kvRow(e.value, val));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(title),
        ...rows,
      ],
    );
  }

  Widget _statusBadge(String label) {
    final lower = label.toLowerCase();
    late Color badgeColor;
    late Color textColor;
    if (lower.contains('abnormal') || lower.contains('heavy')) {
      badgeColor = Colors.redAccent.withValues(alpha: 0.18);
      textColor = Colors.redAccent.shade100;
    } else if (lower.contains('normal') || lower.contains('no growth')) {
      badgeColor = Colors.greenAccent.withValues(alpha: 0.18);
      textColor = Colors.greenAccent.shade100;
    } else {
      badgeColor = _gold.withValues(alpha: 0.15);
      textColor = _goldLight;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(color: textColor, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _interpretationBadge(String interpretation, {String comments = ''}) {
    if (interpretation.isEmpty && comments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Interpretation'),
        if (interpretation.isNotEmpty) _statusBadge(interpretation),
        if (comments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            comments,
            style: GoogleFonts.urbanist(color: Colors.white70, height: 1.45, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _bloodView(Map<String, dynamic> data) {
    const generalLabels = {
      'testDate': 'Test Date',
      'sampleCollectionDate': 'Sample Collection Date',
      'techName': 'Tech Name',
      'notes': 'Notes',
    };
    const resultLabels = {
      'hb': 'Hb',
      'hct': 'HCT',
      'rbc': 'RBC',
      'wbc': 'WBC',
      'plt': 'PLT',
      'mcv': 'MCV',
      'mch': 'MCH',
      'mchc': 'MCHC',
      'rdw': 'RDW',
      'neutrophils': 'Neutrophils %',
      'lymphocytes': 'Lymphocytes %',
      'monocytes': 'Monocytes %',
      'eosinophils': 'Eosinophils %',
      'basophils': 'Basophils %',
    };

    final general = _nestedMap(data, 'generalInfo');
    final results = _nestedMap(data, 'results');
    final interp = _nestedMap(data, 'interpretation');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _mapSection('General Info', general, generalLabels),
        if (results != null && results.isNotEmpty) ...[
          _sectionTitle('Results'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < resultLabels.length; i++) ...[
                  if (_str(results[resultLabels.keys.elementAt(i)]).isNotEmpty) ...[
                    _kvRow(resultLabels.values.elementAt(i), _str(results[resultLabels.keys.elementAt(i)])),
                    if (i < resultLabels.length - 1 &&
                        resultLabels.keys.skip(i + 1).any((k) => _str(results[k]).isNotEmpty))
                      _divider(),
                  ],
                ],
              ],
            ),
          ),
        ],
        _interpretationBadge(
          _str(interp?['interpretation']),
          comments: _str(interp?['comments']),
        ),
      ],
    );
  }

  Widget _urineView(Map<String, dynamic> data) {
    const physicalLabels = {
      'color': 'Color',
      'appearance': 'Appearance',
      'specificGravity': 'Specific Gravity',
      'ph': 'pH',
    };
    const chemicalLabels = {
      'protein': 'Protein',
      'glucose': 'Glucose',
      'ketones': 'Ketones',
      'bilirubin': 'Bilirubin',
      'urobilinogen': 'Urobilinogen',
      'nitrite': 'Nitrite',
      'blood': 'Blood',
      'leukocyteEsterase': 'Leukocyte Esterase',
    };
    const microLabels = {
      'microRbc': 'RBC',
      'microWbc': 'WBC',
      'epithelial': 'Epithelial',
      'casts': 'Casts',
      'crystals': 'Crystals',
      'bacteria': 'Bacteria',
      'yeast': 'Yeast',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _urinePanel('Physical Exam', _nestedMap(data, 'physical'), physicalLabels),
        _urinePanel('Chemical Exam', _nestedMap(data, 'chemical'), chemicalLabels),
        _urinePanel('Microscopic Exam', _nestedMap(data, 'microscopic'), microLabels),
      ],
    );
  }

  Widget _urinePanel(String title, Map<String, dynamic>? section, Map<String, String> labels) {
    if (section == null || section.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (final e in labels.entries) {
      final val = _str(section[e.key]);
      if (val.isNotEmpty) rows.add(_kvRow(e.value, val));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: ThemeData(dividerColor: _gold.withValues(alpha: 0.2)),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        collapsedIconColor: _gold,
        iconColor: _gold,
        title: Text(title, style: GoogleFonts.urbanist(color: _goldLight, fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _cultureView(Map<String, dynamic> data) {
    final culture = _nestedMap(data, 'culture') ?? data;
    final specimen = _str(culture['specimenType']);
    final growth = _str(culture['growthStatus']);
    final organism = _str(culture['organismDetected']);
    final colony = _str(culture['colonyCount']);
    final antibiotics = _nestedList(data, 'antibioticSensitivity');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (specimen.isNotEmpty || growth.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (specimen.isNotEmpty)
                  Text(
                    'Specimen: $specimen',
                    style: GoogleFonts.urbanist(color: _goldLight, fontWeight: FontWeight.w700),
                  ),
                if (growth.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _statusBadge(growth),
                ],
              ],
            ),
          ),
        if (organism.isNotEmpty) _kvRow('Organism Detected', organism),
        if (colony.isNotEmpty) _kvRow('Colony Count', colony),
        if (antibiotics.isNotEmpty) ...[
          _sectionTitle('Antibiotic Sensitivity'),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withValues(alpha: 0.25)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                columnSpacing: 16,
                horizontalMargin: 12,
                columns: [
                  DataColumn(
                    label: Text('Antibiotic', style: GoogleFonts.urbanist(color: _gold, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  DataColumn(
                    label: Text('Result', style: GoogleFonts.urbanist(color: _gold, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
                rows: antibiotics.map((row) {
                  final name = _str(row['antibiotic']);
                  final sens = _str(row['sensitivity']).toUpperCase();
                  Color sensColor;
                  switch (sens) {
                    case 'S':
                      sensColor = Colors.greenAccent.shade100;
                    case 'R':
                      sensColor = Colors.redAccent.shade100;
                    case 'I':
                      sensColor = Colors.amber.shade200;
                    default:
                      sensColor = Colors.white70;
                  }
                  final sensLabel = switch (sens) {
                    'S' => 'Sensitive (S)',
                    'R' => 'Resistant (R)',
                    'I' => 'Intermediate (I)',
                    _ => sens,
                  };
                  return DataRow(
                    cells: [
                      DataCell(Text(name, style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 12))),
                      DataCell(Text(sensLabel, style: GoogleFonts.urbanist(color: sensColor, fontWeight: FontWeight.w700, fontSize: 12))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _biochemistryView(Map<String, dynamic> data) {
    const sections = {
      'bloodGlucose': ('Blood Glucose', {
        'fbs': 'FBS',
        'rbs': 'RBS',
        'hba1c': 'HbA1c',
      }),
      'kidneyFunction': ('Kidney Function', {
        'creatinine': 'Creatinine',
        'bun': 'BUN',
        'uricAcid': 'Uric Acid',
        'egfr': 'eGFR',
      }),
      'liverFunction': ('Liver Function', {
        'alt': 'ALT',
        'ast': 'AST',
        'alp': 'ALP',
        'bilirubin': 'Bilirubin',
        'albumin': 'Albumin',
        'totalProtein': 'Total Protein',
      }),
      'lipidProfile': ('Lipid Profile', {
        'cholesterol': 'Cholesterol',
        'hdl': 'HDL',
        'ldl': 'LDL',
        'triglycerides': 'Triglycerides',
      }),
      'electrolytes': ('Electrolytes', {
        'na': 'Na',
        'k': 'K',
        'cl': 'Cl',
        'ca': 'Ca',
      }),
    };

    final panels = <Widget>[];
    for (final entry in sections.entries) {
      final section = _nestedMap(data, entry.key);
      if (section == null || section.isEmpty) continue;
      final rows = <Widget>[];
      for (final field in entry.value.$2.entries) {
        final val = _str(section[field.key]);
        if (val.isNotEmpty) rows.add(_kvRow(field.value, val));
      }
      if (rows.isEmpty) continue;
      panels.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(entry.value.$1),
            ...rows,
          ],
        ),
      );
    }

    if (panels.isEmpty) return _plainMapView(data);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: panels);
  }

  Widget _plainMapView(Map<String, dynamic> data) {
    final skip = {'testType', 'submittedAt'};
    final rows = <Widget>[];
    for (final e in data.entries) {
      if (skip.contains(e.key)) continue;
      if (e.value is Map) {
        rows.add(_mapSection(e.key, Map<String, dynamic>.from(e.value as Map), {}));
      } else if (e.value != null && _str(e.value).isNotEmpty) {
        rows.add(_kvRow(e.key, _str(e.value)));
      }
    }
    if (rows.isEmpty) {
      return Text('No structured data', style: GoogleFonts.urbanist(color: Colors.white54));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
