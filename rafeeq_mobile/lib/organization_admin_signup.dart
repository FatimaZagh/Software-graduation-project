import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'login_screen.dart';
import 'widgets/rafeeq_back_home_button.dart';

class OrganizationAdminSignupScreen extends StatefulWidget {
  const OrganizationAdminSignupScreen({super.key});

  @override
  State<OrganizationAdminSignupScreen> createState() => _OrganizationAdminSignupScreenState();
}

class _OrganizationAdminSignupScreenState extends State<OrganizationAdminSignupScreen> {
  final orgNameController = TextEditingController();
  final logoUrlController = TextEditingController();
  final subscriptionController = TextEditingController(text: "Free");
  final primaryColorController = TextEditingController(text: "#004D40");
  final accentColorController = TextEditingController(text: "#D4AF37");

  final adminNameController = TextEditingController();
  final adminEmailController = TextEditingController();
  final adminPasswordController = TextEditingController();

  bool _pharmacy = false;
  bool _labRadiology = false;
  bool _internsTrainees = false;
  bool _emergency = false;

  bool _isLoading = false;

  @override
  void dispose() {
    orgNameController.dispose();
    logoUrlController.dispose();
    subscriptionController.dispose();
    primaryColorController.dispose();
    accentColorController.dispose();
    adminNameController.dispose();
    adminEmailController.dispose();
    adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final resp = await http
          .post(
            Uri.parse('$rafeeqApiBase/signup'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "role": "Organization Admin",
              "name": adminNameController.text.trim(),
              "email": adminEmailController.text.trim(),
              "password": adminPasswordController.text,
              "organizationName": orgNameController.text.trim(),
              "organizationLogoUrl": logoUrlController.text.trim(),
              "subscriptionType": subscriptionController.text.trim().isEmpty ? "Free" : subscriptionController.text.trim(),
              "activeModules": {
                "pharmacy": _pharmacy,
                "labRadiology": _labRadiology,
                "internsTrainees": _internsTrainees,
                "emergency": _emergency,
              },
              "theme": {
                "primaryColor": primaryColorController.text.trim(),
                "accentColor": accentColorController.text.trim(),
              }
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Organization created. Pending Super Admin approval.")),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${resp.body}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: rafeeqBackHomeAppBarLeading(context),
        title: const Text('Facility Setup (Org Admin)'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Organization", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    TextField(
                      controller: orgNameController,
                      decoration: const InputDecoration(labelText: "Facility name", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: logoUrlController,
                      decoration: const InputDecoration(
                        labelText: "Logo URL (optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subscriptionController,
                      decoration: const InputDecoration(labelText: "Subscription type", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Text("Modules", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _pharmacy,
                      onChanged: (v) => setState(() => _pharmacy = v),
                      title: const Text("Pharmacy Module"),
                    ),
                    SwitchListTile(
                      value: _labRadiology,
                      onChanged: (v) => setState(() => _labRadiology = v),
                      title: const Text("Lab & Radiology Module"),
                    ),
                    SwitchListTile(
                      value: _internsTrainees,
                      onChanged: (v) => setState(() => _internsTrainees = v),
                      title: const Text("Intern / Trainee Section"),
                    ),
                    SwitchListTile(
                      value: _emergency,
                      onChanged: (v) => setState(() => _emergency = v),
                      title: const Text("Emergency Unit"),
                    ),
                    const SizedBox(height: 16),
                    Text("Branding", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: primaryColorController,
                            decoration: const InputDecoration(
                              labelText: "Primary color (hex)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: accentColorController,
                            decoration: const InputDecoration(
                              labelText: "Accent color (hex)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text("Org Admin account", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    TextField(
                      controller: adminNameController,
                      decoration: const InputDecoration(labelText: "Admin name", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: adminEmailController,
                      decoration: const InputDecoration(labelText: "Admin email", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: adminPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Admin password", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: Text(_isLoading ? "Creating..." : "Create organization"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

