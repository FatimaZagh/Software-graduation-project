import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFFFE8A3);
const _weekDays = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

/// Preset day ranges for quick selection (matches signup chip ordering).
const _dayRangePresets = <String, List<String>>{
  'Sat – Fri': ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
  'Sun – Thu': ['Sun', 'Mon', 'Tue', 'Wed', 'Thu'],
  'Mon – Fri': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
  'Custom': [],
};

/// Operating hours UI — same flow as pharmacy signup (days + native time pickers).
class PharmacyOperatingHoursPicker extends StatefulWidget {
  const PharmacyOperatingHoursPicker({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.usePharmacistTheme = false,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  /// When true, chips/buttons use [PharmacistTheme]-aligned dark styling via callbacks.
  final bool usePharmacistTheme;

  @override
  State<PharmacyOperatingHoursPicker> createState() => _PharmacyOperatingHoursPickerState();
}

class _PharmacyOperatingHoursPickerState extends State<PharmacyOperatingHoursPicker> {
  bool _is24Hours = false;
  String _dayRangeKey = 'Sat – Fri';
  final Set<String> _openDays = {};
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  @override
  void initState() {
    super.initState();
    _parseInitial(widget.initialValue);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void didUpdateWidget(PharmacyOperatingHoursPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && widget.initialValue.isNotEmpty) {
      _parseInitial(widget.initialValue);
      _emit();
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _buildPayload() {
    if (_is24Hours) return '24 Hours';
    final days = _weekDays.where(_openDays.contains).join(', ');
    if (days.isEmpty || _openTime == null || _closeTime == null) return '';
    return '$days · ${_formatTime(_openTime!)} - ${_formatTime(_closeTime!)}';
  }

  void _emit() => widget.onChanged(_buildPayload());

  void _parseInitial(String raw) {
    final s = raw.trim();
    _is24Hours = false;
    _openDays.clear();
    _openTime = null;
    _closeTime = null;
    _dayRangeKey = 'Sat – Fri';

    if (s.isEmpty) {
      _openDays.addAll(_dayRangePresets['Sat – Fri']!);
      _openTime = const TimeOfDay(hour: 8, minute: 0);
      _closeTime = const TimeOfDay(hour: 23, minute: 0);
      return;
    }

    if (s.toLowerCase() == '24 hours') {
      _is24Hours = true;
      return;
    }

    final segments = s.split(RegExp(r'\s*[·•]\s*'));
    if (segments.isNotEmpty) _parseDaysSegment(segments.first);
    if (segments.length > 1) _parseTimesSegment(segments[1]);

    if (_openDays.isEmpty) {
      _openDays.addAll(_dayRangePresets['Sat – Fri']!);
    }
    _openTime ??= const TimeOfDay(hour: 8, minute: 0);
    _closeTime ??= const TimeOfDay(hour: 23, minute: 0);
    _matchDayRangePreset();
  }

  void _parseDaysSegment(String segment) {
    final norm = segment.replaceAll('–', '-').trim();
    if (norm.contains(',')) {
      _dayRangeKey = 'Custom';
      for (final part in norm.split(',')) {
        final d = part.trim();
        if (_weekDays.contains(d)) _openDays.add(d);
      }
      return;
    }
    if (norm.contains('-')) {
      final bounds = norm.split('-').map((e) => e.trim()).toList();
      if (bounds.length == 2) {
        _fillDayRange(bounds[0], bounds[1]);
        _matchDayRangePreset();
        return;
      }
    }
    if (_weekDays.contains(norm)) {
      _openDays.add(norm);
      _dayRangeKey = 'Custom';
    }
  }

  void _fillDayRange(String start, String end) {
    final si = _weekDays.indexOf(start);
    final ei = _weekDays.indexOf(end);
    if (si < 0 || ei < 0) return;
    _openDays.clear();
    if (si <= ei) {
      for (var i = si; i <= ei; i++) {
        _openDays.add(_weekDays[i]);
      }
    } else {
      for (var i = si; i < _weekDays.length; i++) {
        _openDays.add(_weekDays[i]);
      }
      for (var i = 0; i <= ei; i++) {
        _openDays.add(_weekDays[i]);
      }
    }
  }

  void _matchDayRangePreset() {
    for (final entry in _dayRangePresets.entries) {
      if (entry.key == 'Custom') continue;
      if (_setEquals(_openDays, entry.value.toSet())) {
        _dayRangeKey = entry.key;
        return;
      }
    }
    _dayRangeKey = 'Custom';
  }

  bool _setEquals(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  TimeOfDay? _parseClock(String token) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false).firstMatch(token.trim());
    if (m == null) return null;
    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final pm = (m.group(3)!.toUpperCase() == 'PM');
    if (hour == 12) hour = 0;
    if (pm) hour += 12;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _parseTimesSegment(String segment) {
    final m = RegExp(
      r'(\d{1,2}:\d{2}\s*(?:AM|PM))\s*-\s*(\d{1,2}:\d{2}\s*(?:AM|PM))',
      caseSensitive: false,
    ).firstMatch(segment.trim());
    if (m == null) return;
    _openTime = _parseClock(m.group(1)!);
    _closeTime = _parseClock(m.group(2)!);
  }

  void _applyDayRangePreset(String? key) {
    if (key == null) return;
    setState(() {
      _dayRangeKey = key;
      if (key == 'Custom') return;
      _openDays
        ..clear()
        ..addAll(_dayRangePresets[key] ?? []);
      _emit();
    });
  }

  Future<void> _pickTime({required bool isOpen}) async {
    final initial = isOpen
        ? (_openTime ?? const TimeOfDay(hour: 8, minute: 0))
        : (_closeTime ?? const TimeOfDay(hour: 23, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _gold,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (isOpen) {
        _openTime = picked;
      } else {
        _closeTime = picked;
      }
      _emit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildPayload();
    final chipBg = widget.usePharmacistTheme ? const Color(0xFF161616) : const Color(0xFF1A1F1C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Operating Hours', style: GoogleFonts.urbanist(color: _gold, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _is24Hours,
          onChanged: (v) => setState(() {
            _is24Hours = v ?? false;
            if (_is24Hours) {
              _openDays.clear();
              _openTime = null;
              _closeTime = null;
            } else {
              _openDays.addAll(_dayRangePresets[_dayRangeKey] ?? _dayRangePresets['Sat – Fri']!);
              _openTime = const TimeOfDay(hour: 8, minute: 0);
              _closeTime = const TimeOfDay(hour: 23, minute: 0);
            }
            _emit();
          }),
          activeColor: _gold,
          checkColor: Colors.black,
          title: Text('Open 24 hours?', style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (!_is24Hours) ...[
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _dayRangePresets.containsKey(_dayRangeKey) ? _dayRangeKey : 'Custom',
            dropdownColor: const Color(0xFF252525),
            decoration: InputDecoration(
              labelText: 'Days range',
              labelStyle: GoogleFonts.urbanist(color: const Color(0xFFB3B3B3), fontSize: 13),
              filled: true,
              fillColor: chipBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: _gold, width: 1.4),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            items: _dayRangePresets.keys
                .map((k) => DropdownMenuItem(value: k, child: Text(k, style: GoogleFonts.urbanist(color: Colors.white))))
                .toList(),
            onChanged: _applyDayRangePreset,
          ),
          if (_dayRangeKey == 'Custom') ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final day in _weekDays)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(day),
                        selected: _openDays.contains(day),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _openDays.add(day);
                            } else {
                              _openDays.remove(day);
                            }
                            _emit();
                          });
                        },
                        selectedColor: _gold.withValues(alpha: 0.35),
                        checkmarkColor: Colors.black,
                        labelStyle: TextStyle(
                          color: _openDays.contains(day) ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: chipBg,
                        side: BorderSide(color: _gold.withValues(alpha: 0.45)),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(isOpen: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _goldLight,
                    side: BorderSide(color: _gold.withValues(alpha: 0.65)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.wb_sunny_outlined, color: _gold, size: 20),
                  label: Text(
                    _openTime == null ? 'From (open)' : _formatTime(_openTime!),
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(isOpen: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _goldLight,
                    side: BorderSide(color: _gold.withValues(alpha: 0.65)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.nightlight_round, color: _gold, size: 20),
                  label: Text(
                    _closeTime == null ? 'To (close)' : _formatTime(_closeTime!),
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Combined schedule',
            labelStyle: GoogleFonts.urbanist(color: const Color(0xFFB3B3B3), fontSize: 13),
            filled: true,
            fillColor: chipBg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _gold.withValues(alpha: 0.25)),
            ),
            prefixIcon: const Icon(Icons.schedule, color: _gold, size: 20),
          ),
          child: Text(
            preview.isEmpty ? 'Select days and times above' : preview,
            style: GoogleFonts.urbanist(
              color: preview.isEmpty ? Colors.white38 : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
