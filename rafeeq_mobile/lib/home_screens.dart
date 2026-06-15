import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'api_config.dart';
import 'l10n/l10n_extensions.dart';
import 'utils/allergy_display.dart';
import 'login_screen.dart';
import 'patient_portal_screens.dart';
import 'features/patient_dashboard/presentation/patient_emergency_screen.dart';
import 'features/patient_dashboard/presentation/patient_more_features.dart';
import 'features/patient_dashboard/presentation/patient_my_medications_screen.dart';
import 'tenant_state.dart';
import 'widgets/rafeeq_language_toggle.dart';

export 'features/patient_dashboard/presentation/patient_home_screen.dart';

class ReceptionistHomeScreen extends StatefulWidget {
  const ReceptionistHomeScreen({super.key});

  @override
  State<ReceptionistHomeScreen> createState() => _ReceptionistHomeScreenState();
}

class _ReceptionistHomeScreenState extends State<ReceptionistHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<_DoctorToday> _doctorsToday = [
    _DoctorToday(name: 'Dr. Ahmed Hassan', status: 'Available'),
    _DoctorToday(name: 'Dr. Sara Mahmoud', status: 'In Session'),
    _DoctorToday(name: 'Dr. Omar Khaled', status: 'Available'),
    _DoctorToday(name: 'Dr. Layla Farid', status: 'In Session'),
  ];

  late List<_WaitingPatient> _waitingPatients;

  @override
  void initState() {
    super.initState();
    _waitingPatients = [
      _WaitingPatient(
        name: 'Fatima Ali',
        phone: '+966501112233',
        doctor: 'Dr. Ahmed Hassan',
        waitingTime: '8 min',
      ),
      _WaitingPatient(
        name: 'Yousef Adel',
        phone: '+966504445566',
        doctor: 'Dr. Sara Mahmoud',
        waitingTime: '15 min',
      ),
      _WaitingPatient(
        name: 'Noura Salem',
        phone: '+966507778899',
        doctor: 'Dr. Omar Khaled',
        waitingTime: '22 min',
      ),
      _WaitingPatient(
        name: 'Khalid Ibrahim',
        phone: '+966509990011',
        doctor: 'Dr. Layla Farid',
        waitingTime: '5 min',
      ),
    ];
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<_WaitingPatient> get _filteredWaiting {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _waitingPatients;
    return _waitingPatients.where((p) {
      return p.name.toLowerCase().contains(q) || p.phone.replaceAll(' ', '').contains(q);
    }).toList();
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final crossAxis = w >= 800 ? 4 : 2;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(context.l10n.authReceptionistPortal),
        elevation: 0,
        backgroundColor: Color(0xFF37474F),
        foregroundColor: Colors.white,
        actions: const [RafeeqLanguageToggle()],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF37474F)),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    context.l10n.authFrontDesk,
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.calendar_today_outlined),
                title: Text(context.l10n.authDailySchedule),
                onTap: () {
                  Navigator.pop(context);
                  _snack('Daily Schedule');
                },
              ),
              ListTile(
                leading: Icon(Icons.person_add_alt_outlined),
                title: Text(context.l10n.authPatientRegistration),
                onTap: () {
                  Navigator.pop(context);
                  _snack('Patient Registration');
                },
              ),
              ListTile(
                leading: Icon(Icons.receipt_long_outlined),
                title: Text(context.l10n.authBilling),
                onTap: () {
                  Navigator.pop(context);
                  _snack('Billing');
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade700),
                title: Text(context.l10n.logout),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth > 1000 ? 960.0 : constraints.maxWidth;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: w < 400 ? 12 : 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or phoneâ€¦',
                        prefixIcon: Icon(Icons.search, color: Color(0xFF546E7A)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Today's Doctors",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF37474F),
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _doctorsToday.length,
                        separatorBuilder: (_, __) => SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final d = _doctorsToday[i];
                          final inSession = d.status == 'In Session';
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Color(0xFFE0E0E0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.medical_services_outlined, size: 18, color: Color(0xFF546E7A)),
                                SizedBox(width: 8),
                                Text(d.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: inSession ? Colors.orange.shade50 : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    d.status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: inSession ? Colors.orange.shade800 : Colors.green.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxis,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: w >= 800 ? 1.35 : 1.05,
                      children: [
                        _recvTile(
                          title: 'Register New Patient',
                          icon: Icons.person_add,
                          color: Color(0xFF455A64),
                          onTap: () => _snack('Register New Patient'),
                        ),
                        _recvTile(
                          title: 'Check-in Patient',
                          icon: Icons.how_to_reg,
                          color: Color(0xFF546E7A),
                          onTap: () => _snack('Patient marked as Arrived'),
                        ),
                        _recvTile(
                          title: 'Find Doctor',
                          icon: Icons.search,
                          color: Color(0xFF607D8B),
                          onTap: () => _snack('Doctor availability'),
                        ),
                        _recvTile(
                          title: 'Emergency Alert',
                          icon: Icons.emergency_share,
                          color: Colors.red,
                          onTap: () => _snack('Emergency alert sent (placeholder)'),
                        ),
                      ],
                    ),
                    SizedBox(height: 22),
                    Text(
                      'In the Waiting Room',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF263238),
                      ),
                    ),
                    SizedBox(height: 10),
                    if (_filteredWaiting.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No patients match your search.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF78909C)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _filteredWaiting.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final p = _filteredWaiting[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                                  ),
                                  SizedBox(height: 6),
                                  Text('Doctor: ${p.doctor}', style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
                                  SizedBox(height: 4),
                                  Text('Waiting: ${p.waitingTime}', style: TextStyle(fontSize: 13, color: Color(0xFF78909C))),
                                  SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _snack('${p.name} â†’ clinic'),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Color(0xFFECEFF1),
                                        foregroundColor: Color(0xFF37474F),
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text('Send to Clinic'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _recvTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFE0E0E0)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF37474F)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorToday {
  final String name;
  final String status;
  _DoctorToday({required this.name, required this.status});
}

class _WaitingPatient {
  final String name;
  final String phone;
  final String doctor;
  final String waitingTime;
  _WaitingPatient({
    required this.name,
    required this.phone,
    required this.doctor,
    required this.waitingTime,
  });
}

class PharmacistHomeScreen extends StatefulWidget {
  const PharmacistHomeScreen({super.key});

  @override
  State<PharmacistHomeScreen> createState() => _PharmacistHomeScreenState();
}

class _PharmacistHomeScreenState extends State<PharmacistHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  late List<_PharmacyPrescription> _rxList;

  @override
  void initState() {
    super.initState();
    _rxList = [
      _PharmacyPrescription(
        prescriptionId: 'RX-2026-0041',
        patientName: 'Fatima Ali',
        patientId: 'P-1001',
        doctorName: 'Dr. Ahmed Hassan',
        status: 'Pending',
        instructions: 'Take after meals. Complete the antibiotic course even if symptoms improve.',
        lines: [
          _MedLine(name: 'Panadol', strength: '500mg', frequency: '3 times/day'),
          _MedLine(name: 'Amoxicillin', strength: '250mg', frequency: '2 times/day'),
        ],
      ),
      _PharmacyPrescription(
        prescriptionId: 'RX-2026-0042',
        patientName: 'Omar Khaled',
        patientId: 'P-1002',
        doctorName: 'Dr. Sara Mahmoud',
        status: 'Pending',
        instructions: 'Monitor blood pressure. Avoid NSAIDs.',
        lines: [
          _MedLine(name: 'Amlodipine', strength: '5mg', frequency: 'Once daily'),
        ],
      ),
      _PharmacyPrescription(
        prescriptionId: 'RX-2026-0043',
        patientName: 'Noura Salem',
        patientId: 'P-1003',
        doctorName: 'Dr. Ahmed Hassan',
        status: 'Pending',
        instructions: 'Use inhaler for acute symptoms only.',
        lines: [
          _MedLine(name: 'Salbutamol', strength: '100mcg', frequency: 'As needed'),
          _MedLine(name: 'Vitamin D', strength: '1000 IU', frequency: 'Once daily'),
        ],
      ),
    ];
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_PharmacyPrescription> get _pendingQueue {
    return _rxList.where((r) => r.status == 'Pending').toList();
  }

  List<_PharmacyPrescription> get _filteredPending {
    final q = _searchController.text.trim().toLowerCase();
    final list = _pendingQueue;
    if (q.isEmpty) return list;
    return list.where((r) {
      return r.patientName.toLowerCase().contains(q) || r.prescriptionId.toLowerCase().contains(q);
    }).toList();
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openDetail(_PharmacyPrescription rx) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _PharmacyDetailScreen(prescription: rx),
      ),
    );
    if (result == true && mounted) {
      setState(() {});
      _snack('Prescription marked as Dispensed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final indigo = Colors.indigo;
    final filtered = _filteredPending;

    return Scaffold(
      backgroundColor: indigo.shade50,
      appBar: AppBar(
        title: Text(context.l10n.authPharmacyPortal),
        actions: const [RafeeqLanguageToggle()],
        elevation: 0,
        backgroundColor: indigo.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: indigo.shade700),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_pharmacy, color: Colors.white, size: 36),
                      SizedBox(height: 8),
                      Text(
                        'Pharmacy',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.queue_outlined),
                title: Text(context.l10n.authPrescriptionsQueue),
                onTap: () {
                  Navigator.pop(context);
                  _snack('Prescriptions Queue');
                },
              ),
              ListTile(
                leading: Icon(Icons.inventory_2_outlined),
                title: Text(context.l10n.authInventoryManagement),
                onTap: () {
                  Navigator.pop(context);
                  _snack('Inventory Management');
                },
              ),
              ListTile(
                leading: Icon(Icons.history),
                title: Text(context.l10n.authMedicationHistory),
                onTap: () {
                  Navigator.pop(context);
                  _snack('Medication History');
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade700),
                title: Text(context.l10n.logout),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth > 1000 ? 960.0 : constraints.maxWidth;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by patient name or prescription IDâ€¦',
                              prefixIcon: Icon(Icons.search, color: indigo.shade700),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: indigo.shade100),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Tooltip(
                          message: 'Scan QR (placeholder)',
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: indigo.shade600,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _snack('QR scan (placeholder)'),
                            icon: Icon(Icons.qr_code_scanner),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Prescription orders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: indigo.shade900,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No pending prescriptions match your search.',
                              style: TextStyle(color: indigo.shade400),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final rx = filtered[index];
                              return Card(
                                elevation: 1,
                                margin: EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: EdgeInsets.all(14),
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
                                                  rx.patientName,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: indigo.shade900,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'ID: ${rx.patientId}',
                                                  style: TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Prescribing doctor: ${rx.doctorName}',
                                                  style: TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.orange.shade200),
                                            ),
                                            child: Text(
                                              rx.status,
                                              style: TextStyle(
                                                color: Colors.orange.shade900,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        rx.prescriptionId,
                                        style: TextStyle(fontSize: 12, color: indigo.shade400),
                                      ),
                                      SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: indigo.shade600,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => _openDetail(rx),
                                          icon: Icon(Icons.medication_liquid, size: 18),
                                          label: Text('View Medication'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PharmacyDetailScreen extends StatelessWidget {
  final _PharmacyPrescription prescription;

  _PharmacyDetailScreen({required this.prescription});

  @override
  Widget build(BuildContext context) {
    final indigo = Colors.indigo;

    return Scaffold(
      backgroundColor: indigo.shade50,
      appBar: AppBar(
        title: Text('Prescription ${prescription.prescriptionId}'),
        backgroundColor: indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prescription.patientName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Patient ID: ${prescription.patientId}', style: TextStyle(color: Color(0xFF546E7A))),
                    SizedBox(height: 4),
                    Text('Prescribing doctor: ${prescription.doctorName}', style: TextStyle(color: Color(0xFF546E7A))),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Medicines',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: indigo.shade900),
            ),
            SizedBox(height: 8),
            ...prescription.lines.map((line) {
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.medication, color: indigo.shade700),
                  title: Text(
                    '${line.name} â€” ${line.strength}',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(line.frequency),
                ),
              );
            }),
            SizedBox(height: 16),
            Text(
              "Doctor's instructions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: indigo.shade900),
            ),
            SizedBox(height: 8),
            Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  prescription.instructions,
                  style: TextStyle(height: 1.4, color: Color(0xFF37474F)),
                ),
              ),
            ),
            SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                prescription.status = 'Dispensed';
                Navigator.pop(context, true);
              },
              icon: Icon(Icons.check_circle_outline),
              label: Text('Dispense Medication'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PharmacyPrescription {
  String prescriptionId;
  String patientName;
  String patientId;
  String doctorName;
  String status;
  String instructions;
  List<_MedLine> lines;

  _PharmacyPrescription({
    required this.prescriptionId,
    required this.patientName,
    required this.patientId,
    required this.doctorName,
    required this.status,
    required this.instructions,
    required this.lines,
  });
}

class _MedLine {
  final String name;
  final String strength;
  final String frequency;
  _MedLine({required this.name, required this.strength, required this.frequency});
}

class TraineeHomeScreen extends StatefulWidget {
  const TraineeHomeScreen({super.key});

  @override
  State<TraineeHomeScreen> createState() => _TraineeHomeScreenState();
}

class _TraineeHomeScreenState extends State<TraineeHomeScreen> {
  final double _hoursCompleted = 40;
  final double _hoursTotal = 100;
  final String _supervisorName = 'Dr. Layla Farid';
  final String _department = 'Internal Medicine';

  /// Placeholder schedule lines for UI preview only.
  final List<String> _schedulePreview = const [
    'Mon 09:00 â€” Ward rounds (observation)',
    'Wed 14:00 â€” Case discussion (Room B2)',
    'Fri 10:00 â€” Skills lab',
  ];

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final crossAxis = w >= 700 ? 3 : 1;
    final progress = (_hoursCompleted / _hoursTotal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Color(0xFFECEFF1),
      appBar: AppBar(
        title: Text(context.l10n.authLearningPortal),
        actions: const [RafeeqLanguageToggle()],
        elevation: 0,
        backgroundColor: Color(0xFF546E7A),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF546E7A)),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Trainee',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.remove_red_eye_outlined),
                title: Text(context.l10n.authObservationMode),
                onTap: () {
                  Navigator.pop(context);
                  _snack('Observation mode â€” read-only (preview)');
                },
              ),
              ListTile(
                leading: Icon(Icons.local_library_outlined),
                title: Text(context.l10n.authMedicalLibrary),
                onTap: () {
                  Navigator.pop(context);
                  _snack('Medical Library (preview)');
                },
              ),
              ListTile(
                leading: Icon(Icons.calendar_month_outlined),
                title: Text(context.l10n.authTrainingSchedule),
                onTap: () {
                  Navigator.pop(context);
                  _snack('Training Schedule:\n${_schedulePreview.join('\n')}');
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade700),
                title: Text(context.l10n.logout),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth > 900 ? 880.0 : constraints.maxWidth;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: w < 400 ? 12 : 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Observation hub',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF37474F),
                      ),
                    ),
                    SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxis,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: w >= 700 ? 1.25 : 1.5,
                      children: [
                        _traineeHubTile(
                          title: 'Live Consultations',
                          subtitle: 'Read-only sessions',
                          icon: Icons.visibility,
                          onTap: () => _snack('Live consultations list (read-only preview)'),
                        ),
                        _traineeHubTile(
                          title: 'Case Studies',
                          subtitle: 'Anonymous cases',
                          icon: Icons.menu_book,
                          onTap: () => _snack('Case library (placeholder): 12 cases available'),
                        ),
                        _traineeHubTile(
                          title: 'Hospital Map',
                          subtitle: 'Departments layout',
                          icon: Icons.map,
                          onTap: () => _snack('Hospital map (placeholder)'),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      'My supervisor',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF37474F),
                      ),
                    ),
                    SizedBox(height: 10),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Color(0xFF78909C),
                                  child: Icon(Icons.school, color: Colors.white),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _supervisorName,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF263238),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Department: $_department',
                                        style: TextStyle(color: Color(0xFF546E7A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _snack('Message supervisor (preview â€” read-only chat not enabled)'),
                                icon: Icon(Icons.chat_bubble_outline),
                                label: Text('Message Supervisor'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Color(0xFF37474F),
                                  side: BorderSide(color: Color(0xFF90A4AE)),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 22),
                    Text(
                      'Training hours completed',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF37474F),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${_hoursCompleted.toInt()} / ${_hoursTotal.toInt()} hours',
                      style: TextStyle(color: Color(0xFF607D8B), fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Color(0xFFCFD8DC),
                        color: Color(0xFF546E7A),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Trainee access (read-only)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF607D8B),
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Tooltip(
                          message: 'Editing disabled for trainees',
                          child: FilledButton.icon(
                            onPressed: null,
                            icon: Icon(Icons.edit_off),
                            label: Text('Edit record'),
                          ),
                        ),
                        Tooltip(
                          message: 'Prescribing disabled for trainees',
                          child: FilledButton.icon(
                            onPressed: null,
                            icon: Icon(Icons.medication_outlined),
                            label: Text('Prescribe'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _traineeHubTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFFE0E0E0)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Color(0xFF546E7A)),
              SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF37474F)),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF78909C)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PatientDetailsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String appointmentId;
  final _PatientHistory history;

  PatientDetailsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.appointmentId,
    required this.history,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  final diagnosisController = TextEditingController();
  final prescriptionController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    diagnosisController.dispose();
    prescriptionController.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.blueGrey.shade900,
        ),
      ),
    );
  }

  Widget _chipList(List<String> items) {
    if (items.isEmpty) {
      return Text('None', style: TextStyle(color: Colors.blueGrey.shade700));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (e) => Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(e, style: TextStyle(color: Colors.blueGrey.shade900)),
            ),
          )
          .toList(),
    );
  }

  List<Map<String, String>> _prescriptionPayload() {
    final text = prescriptionController.text.trim();
    if (text.isEmpty) return [];
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map(
          (line) => <String, String>{
            'name': line,
            'dosage': '',
            'frequency': '',
          },
        )
        .toList();
  }

  Future<void> _saveAndComplete() async {
    if (_sending) return;
    final diagnosis = diagnosisController.text.trim();
    if (diagnosis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a diagnosis.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final createUri = Uri.parse('$rafeeqApiBase/api/medical-records/create');
      final createResponse = await http
          .post(
            createUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'appointmentId': widget.appointmentId,
              'diagnosis': diagnosis,
              'prescription': _prescriptionPayload(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (createResponse.statusCode != 201 && createResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save record: ${createResponse.body}')),
        );
        return;
      }

      final updateUri = Uri.parse('$rafeeqApiBase/api/appointments/update-status');
      final updateResponse = await http
          .put(
            updateUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'appointmentId': widget.appointmentId,
              'status': 'Completed',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (updateResponse.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Examination saved and appointment completed.')),
        );
        Navigator.pop(
          context,
          _AppointmentUpdate(appointmentId: widget.appointmentId, newStatus: 'Completed'),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Medical record saved, but status update failed: ${updateResponse.body}',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed. Check your connection.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        title: Text(context.l10n.authPatientDetails),
        backgroundColor: Colors.blueGrey.shade700,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.blueGrey.shade700,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.patientName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.blueGrey.shade900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Patient ID: ${widget.patientId}',
                            style: TextStyle(color: Colors.blueGrey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _sectionTitle('Medical History'),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chronic Diseases', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900)),
                    SizedBox(height: 8),
                    _chipList(widget.history.chronicDiseases),
                    SizedBox(height: 14),
                    Text('Allergies', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900)),
                    SizedBox(height: 8),
                    _chipList(parseAllergyMedicationNames(widget.history.allergies)),
                    SizedBox(height: 14),
                    Text('Medications', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900)),
                    SizedBox(height: 8),
                    _chipList(widget.history.medications),
                    SizedBox(height: 14),
                    Text('Notes', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900)),
                    SizedBox(height: 8),
                    Text(
                      widget.history.notes.isEmpty ? 'None' : widget.history.notes,
                      style: TextStyle(color: Colors.blueGrey.shade700),
                    ),
                  ],
                ),
              ),
            ),

            _sectionTitle('Doctor Input'),
            TextField(
              controller: diagnosisController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Diagnosis',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: prescriptionController,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Prescription',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _sending ? null : _saveAndComplete,
                icon: Icon(Icons.check_circle),
                label: Text(_sending ? 'Saving...' : 'Save & Complete'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentUpdate {
  final String appointmentId;
  final String newStatus;

  _AppointmentUpdate({required this.appointmentId, required this.newStatus});
}

class _Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String date;
  final String time;
  final String status;
  final _PatientHistory history;

  _Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.time,
    required this.status,
    required this.history,
  });

  factory _Appointment.fromJson(Map<String, dynamic> json) {
    String patientIdStr = '';
    final dynamic pid = json['patientId'];
    if (pid is Map<String, dynamic>) {
      patientIdStr = pid['_id']?.toString() ?? '';
    } else if (pid != null) {
      patientIdStr = pid.toString();
    }

    return _Appointment(
      id: json['_id']?.toString() ?? '',
      patientId: patientIdStr,
      patientName: json['patientName']?.toString() ?? 'Unknown',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Waiting',
      history: _PatientHistory(
        chronicDiseases: [],
        allergies: [],
        medications: [],
        notes: 'No medical history on file for this appointment.',
      ),
    );
  }

  _Appointment copyWith({String? status}) {
    return _Appointment(
      id: id,
      patientId: patientId,
      patientName: patientName,
      date: date,
      time: time,
      status: status ?? this.status,
      history: history,
    );
  }
}

class _PatientHistory {
  final List<String> chronicDiseases;
  final List<String> allergies;
  final List<String> medications;
  final String notes;

  _PatientHistory({
    required this.chronicDiseases,
    required this.allergies,
    required this.medications,
    required this.notes,
  });
}

