import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/auth/presentation/auth_signup_theme.dart';

/// Opens or previews a diagnostic attachment (HTTP URL or inline data URI).
Future<void> openDiagnosticAttachment(
  BuildContext context, {
  required String url,
  String? fileName,
  String? mimeType,
}) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;

  try {
    if (trimmed.startsWith('data:')) {
      final comma = trimmed.indexOf(',');
      if (comma < 0) throw Exception('Invalid attachment data');
      final header = trimmed.substring(0, comma);
      final payload = trimmed.substring(comma + 1);
      final bytes = base64Decode(payload);
      final isImage = header.contains('image/') ||
          (mimeType ?? '').startsWith('image/') ||
          (fileName ?? '').toLowerCase().endsWith('.png') ||
          (fileName ?? '').toLowerCase().endsWith('.jpg') ||
          (fileName ?? '').toLowerCase().endsWith('.jpeg');

      if (isImage && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: AuthSignupColors.glassCard,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fileName ?? 'Attachment',
                            style: GoogleFonts.urbanist(color: AuthSignupColors.goldLight, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Flexible(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))),
                ],
              ),
            ),
          ),
        );
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${fileName ?? 'Document'} attached — preview available on supported devices')),
        );
      }
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) throw Exception('Invalid attachment URL');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open attachment');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
