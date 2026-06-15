import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);

String normalizeLabTestType(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'blood':
      return 'Blood';
    case 'urine':
      return 'Urine';
    case 'culture':
      return 'Culture';
    case 'biochemistry':
      return 'Biochemistry';
    default:
      return raw.trim().isEmpty ? 'Blood' : raw.trim();
  }
}

InputDecoration labFieldDec(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _kGold.withValues(alpha: 0.9), fontSize: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _kGold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _kGold),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );

/// Holds controllers and dropdown values for one active order form.
class LabResultFormHolder {
  LabResultFormHolder();

  final Map<String, dynamic> resultData = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _dropdowns = {};
  final List<AntibioticSensitivityRow> antibioticRows = [AntibioticSensitivityRow()];

  TextEditingController ctrl(String key, {String initial = ''}) {
    return _controllers.putIfAbsent(key, () => TextEditingController(text: initial));
  }

  String? dropdown(String key) => _dropdowns[key];

  void setDropdown(String key, String? value) {
    _dropdowns[key] = value;
    if (value != null) resultData[key] = value;
  }

  void syncFromControllers() {
    for (final e in _controllers.entries) {
      final v = e.value.text.trim();
      if (v.isNotEmpty) resultData[e.key] = v;
    }
    for (final e in _dropdowns.entries) {
      if (e.value != null && e.value!.isNotEmpty) resultData[e.key] = e.value;
    }
  }

  Map<String, dynamic> collectPayload(String testType) {
    syncFromControllers();
    final type = normalizeLabTestType(testType);
    final payload = <String, dynamic>{
      'testType': type,
      'submittedAt': DateTime.now().toIso8601String(),
    };

    switch (type) {
      case 'Blood':
        payload['generalInfo'] = _pick([
          'testDate',
          'sampleCollectionDate',
          'techName',
          'notes',
        ]);
        payload['results'] = _pick([
          'hb',
          'hct',
          'rbc',
          'wbc',
          'plt',
          'mcv',
          'mch',
          'mchc',
          'rdw',
          'neutrophils',
          'lymphocytes',
          'monocytes',
          'eosinophils',
          'basophils',
        ]);
        payload['interpretation'] = _pick(['interpretation', 'comments']);
      case 'Urine':
        payload['physical'] = _pick(['color', 'appearance', 'specificGravity', 'ph']);
        payload['chemical'] = _pick([
          'protein',
          'glucose',
          'ketones',
          'bilirubin',
          'urobilinogen',
          'nitrite',
          'blood',
          'leukocyteEsterase',
        ]);
        payload['microscopic'] = _pick([
          'microRbc',
          'microWbc',
          'epithelial',
          'casts',
          'crystals',
          'bacteria',
          'yeast',
        ]);
      case 'Culture':
        payload['culture'] = _pick([
          'specimenType',
          'organismDetected',
          'colonyCount',
          'growthStatus',
        ]);
        payload['antibioticSensitivity'] = antibioticRows
            .map((r) => r.toMap())
            .where((m) => m['antibiotic'] != null && (m['antibiotic'] as String).isNotEmpty)
            .toList();
      case 'Biochemistry':
        payload['bloodGlucose'] = _pick(['fbs', 'rbs', 'hba1c']);
        payload['kidneyFunction'] = _pick(['creatinine', 'bun', 'uricAcid', 'egfr']);
        payload['liverFunction'] = _pick(['alt', 'ast', 'alp', 'bilirubin', 'albumin', 'totalProtein']);
        payload['lipidProfile'] = _pick(['cholesterol', 'hdl', 'ldl', 'triglycerides']);
        payload['electrolytes'] = _pick(['na', 'k', 'cl', 'ca']);
      default:
        payload['notes'] = resultData['genericNotes'] ?? ctrl('genericNotes').text.trim();
    }

    payload.removeWhere((_, v) => v is Map && v.isEmpty);
    return payload;
  }

  Map<String, dynamic> _pick(List<String> keys) {
    final m = <String, dynamic>{};
    for (final k in keys) {
      final v = resultData[k] ?? _controllers[k]?.text.trim();
      if (v != null && v.toString().isNotEmpty) m[k] = v;
    }
    return m;
  }

  String toJson(String testType) => jsonEncode(collectPayload(testType));

  bool hasMinimumData(String testType) {
    syncFromControllers();
    final payload = collectPayload(testType);
    if (payload.length <= 2) return false;
    for (final entry in payload.entries) {
      if (entry.key == 'testType' || entry.key == 'submittedAt') continue;
      if (entry.value is Map && (entry.value as Map).isNotEmpty) return true;
      if (entry.value is List && (entry.value as List).isNotEmpty) return true;
      if (entry.value != null && entry.value.toString().isNotEmpty) return true;
    }
    return false;
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    for (final r in antibioticRows) {
      r.dispose();
    }
    antibioticRows.clear();
    resultData.clear();
    _dropdowns.clear();
  }
}

class AntibioticSensitivityRow {
  AntibioticSensitivityRow();

  final TextEditingController nameCtrl = TextEditingController();
  String sensitivity = 'S';

  Map<String, String> toMap() => {
        'antibiotic': nameCtrl.text.trim(),
        'sensitivity': sensitivity,
      };

  void dispose() => nameCtrl.dispose();
}

/// Dynamic result entry UI keyed by [testType].
class LabResultDynamicForm extends StatelessWidget {
  const LabResultDynamicForm({
    super.key,
    required this.testType,
    required this.holder,
    required this.onChanged,
  });

  final String testType;
  final LabResultFormHolder holder;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _buildDynamicResultForm(normalizeLabTestType(testType));
  }

  Widget _buildDynamicResultForm(String type) {
    switch (type) {
      case 'Blood':
        return _bloodForm();
      case 'Urine':
        return _urineForm();
      case 'Culture':
        return _cultureForm();
      case 'Biochemistry':
        return _biochemistryForm();
      default:
        return _genericForm();
    }
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.poppins(
            color: _kGold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _field(String key, String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: holder.ctrl(key),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: labFieldDec(label),
        onChanged: (_) => onChanged(),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }

  Widget _row2(String k1, String l1, String k2, String l2) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _field(k1, l1)),
          const SizedBox(width: 8),
          Expanded(child: _field(k2, l2)),
        ],
      ),
    );
  }

  Widget _dropdown(String key, String label, List<String> options, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        value: holder.dropdown(key),
        dropdownColor: const Color(0xFF1A2220),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: labFieldDec(label),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (v) {
          holder.setDropdown(key, v);
          onChanged();
        },
        validator: required ? (v) => v == null || v.isEmpty ? '$label is required' : null : null,
      ),
    );
  }

  Widget _expansionSection(String title, List<Widget> children) {
    return Theme(
      data: ThemeData(dividerColor: _kGold.withValues(alpha: 0.25)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        collapsedIconColor: _kGold,
        iconColor: _kGold,
        title: Text(title, style: GoogleFonts.poppins(color: _kGoldLight, fontWeight: FontWeight.w600, fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _bloodForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('General Info'),
        _row2('testDate', 'Test Date', 'sampleCollectionDate', 'Sample Collection Date'),
        _field('techName', 'Tech Name'),
        _field('notes', 'Notes'),
        _sectionTitle('Results'),
        _row2('hb', 'Hb', 'hct', 'HCT'),
        _row2('rbc', 'RBC', 'wbc', 'WBC'),
        _row2('plt', 'PLT', 'mcv', 'MCV'),
        _row2('mch', 'MCH', 'mchc', 'MCHC'),
        _field('rdw', 'RDW'),
        _row2('neutrophils', 'Neutrophils %', 'lymphocytes', 'Lymphocytes %'),
        _row2('monocytes', 'Monocytes %', 'eosinophils', 'Eosinophils %'),
        _field('basophils', 'Basophils %'),
        _sectionTitle('Interpretation'),
        _dropdown('interpretation', 'Normal / Abnormal', const ['Normal', 'Abnormal']),
        _field('comments', 'Comments'),
      ],
    );
  }

  Widget _urineForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _expansionSection('Physical', [
          _row2('color', 'Color', 'appearance', 'Appearance'),
          _row2('specificGravity', 'Specific Gravity', 'ph', 'pH'),
        ]),
        _expansionSection('Chemical', [
          _row2('protein', 'Protein', 'glucose', 'Glucose'),
          _row2('ketones', 'Ketones', 'bilirubin', 'Bilirubin'),
          _row2('urobilinogen', 'Urobilinogen', 'nitrite', 'Nitrite'),
          _row2('blood', 'Blood', 'leukocyteEsterase', 'Leukocyte Esterase'),
        ]),
        _expansionSection('Microscopic', [
          _row2('microRbc', 'RBC', 'microWbc', 'WBC'),
          _row2('epithelial', 'Epithelial', 'casts', 'Casts'),
          _row2('crystals', 'Crystals', 'bacteria', 'Bacteria'),
          _field('yeast', 'Yeast'),
        ]),
      ],
    );
  }

  Widget _cultureForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Culture & Sensitivity'),
        _dropdown(
          'specimenType',
          'Specimen Type',
          const ['Urine', 'Blood', 'Sputum', 'Wound', 'Stool', 'Other'],
        ),
        _field('organismDetected', 'Organism Detected'),
        _field('colonyCount', 'Colony Count'),
        _dropdown(
          'growthStatus',
          'Growth Status',
          const ['No Growth', 'Light', 'Moderate', 'Heavy'],
        ),
        _sectionTitle('Antibiotic Sensitivity'),
        ...holder.antibioticRows.asMap().entries.map((e) => _antibioticRow(e.key, e.value)),
        TextButton.icon(
          onPressed: () {
            holder.antibioticRows.add(AntibioticSensitivityRow());
            onChanged();
          },
          icon: const Icon(Icons.add, color: _kGold, size: 18),
          label: Text('Add antibiotic', style: GoogleFonts.poppins(color: _kGoldLight, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _antibioticRow(int index, AntibioticSensitivityRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row.nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: labFieldDec('Antibiotic Name'),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: row.sensitivity,
              dropdownColor: const Color(0xFF1A2220),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: labFieldDec('S / I / R'),
              items: const [
                DropdownMenuItem(value: 'S', child: Text('Sensitive (S)')),
                DropdownMenuItem(value: 'I', child: Text('Intermediate (I)')),
                DropdownMenuItem(value: 'R', child: Text('Resistant (R)')),
              ],
              onChanged: (v) {
                if (v != null) {
                  row.sensitivity = v;
                  onChanged();
                }
              },
            ),
          ),
          if (holder.antibioticRows.length > 1)
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.redAccent.withValues(alpha: 0.85), size: 20),
              onPressed: () {
                row.dispose();
                holder.antibioticRows.removeAt(index);
                onChanged();
              },
            ),
        ],
      ),
    );
  }

  Widget _biochemistryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _expansionSection('Blood Glucose', [
          _row2('fbs', 'FBS', 'rbs', 'RBS'),
          _field('hba1c', 'HbA1c'),
        ]),
        _expansionSection('Kidney Function', [
          _row2('creatinine', 'Creatinine', 'bun', 'BUN'),
          _row2('uricAcid', 'Uric Acid', 'egfr', 'eGFR'),
        ]),
        _expansionSection('Liver Function', [
          _row2('alt', 'ALT', 'ast', 'AST'),
          _row2('alp', 'ALP', 'bilirubin', 'Bilirubin'),
          _row2('albumin', 'Albumin', 'totalProtein', 'Total Protein'),
        ]),
        _expansionSection('Lipid Profile', [
          _row2('cholesterol', 'Cholesterol', 'hdl', 'HDL'),
          _row2('ldl', 'LDL', 'triglycerides', 'Triglycerides'),
        ]),
        _expansionSection('Electrolytes', [
          _row2('na', 'Na', 'k', 'K'),
          _row2('cl', 'Cl', 'ca', 'Ca'),
        ]),
      ],
    );
  }

  Widget _genericForm() {
    return _field('genericNotes', 'Result analysis / clinical notes', required: true);
  }
}
