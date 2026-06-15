import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'pharmacist_theme.dart';

/// Premium circular profile photo picker with gold camera overlay.
class PharmacistProfilePhotoPicker extends StatelessWidget {
  const PharmacistProfilePhotoPicker({
    super.key,
    required this.imageData,
    required this.onPick,
    this.radius = 52,
  });

  final String imageData;
  final VoidCallback onPick;
  final double radius;

  ImageProvider? get _provider {
    final raw = imageData.trim();
    if (raw.isEmpty) return null;
    try {
      final b64 = raw.contains(',') ? raw.split(',').last : raw;
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onPick,
            child: CircleAvatar(
              radius: radius,
              backgroundColor: PharmacistTheme.gold.withValues(alpha: 0.15),
              backgroundImage: _provider,
              child: _provider == null
                  ? Icon(Icons.person, size: radius, color: PharmacistTheme.gold.withValues(alpha: 0.85))
                  : null,
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Material(
              color: PharmacistTheme.gold,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                onTap: onPick,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.black, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> pickPharmacistProfilePhoto() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, imageQuality: 85);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

Widget pharmacistPhotoHint() => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'Upload a professional photo for your pharmacy profile',
        textAlign: TextAlign.center,
        style: GoogleFonts.urbanist(color: PharmacistTheme.greyText, fontSize: 13),
      ),
    );
