import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Premium dark-theme chat bubble palette (matches Rafeeq gold workspace).
abstract final class RafeeqChatBubbleColors {
  static const sentBackground = Color(0xFFC9A227);
  static const sentText = Color(0xDE000000); // black87
  static const receivedBackground = Color(0xFF1E1E1E);
  static const receivedText = Colors.white;
  static const timestamp = Color(0x8AFFFFFF); // white54
}

/// Production-grade chat bubble with asymmetric corners and optional timestamp.
class RafeeqChatBubble extends StatelessWidget {
  const RafeeqChatBubble({
    super.key,
    required this.isMe,
    required this.text,
    this.timestamp,
    this.maxWidthFactor = 0.75,
  });

  final bool isMe;
  final String text;
  final DateTime? timestamp;
  final double maxWidthFactor;

  static String? formatTimestamp(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final displayText = text.trim().isEmpty ? '(empty message)' : text.trim();
    final timeLabel = formatTimestamp(timestamp);

    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth * maxWidthFactor),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? RafeeqChatBubbleColors.sentBackground : RafeeqChatBubbleColors.receivedBackground,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isMe ? 0.22 : 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                displayText,
                style: GoogleFonts.urbanist(
                  color: isMe ? RafeeqChatBubbleColors.sentText : RafeeqChatBubbleColors.receivedText,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (timeLabel != null)
              Padding(
                padding: EdgeInsets.only(
                  left: isMe ? 0 : 12,
                  right: isMe ? 12 : 0,
                  bottom: 2,
                ),
                child: Text(
                  timeLabel,
                  style: GoogleFonts.urbanist(
                    color: RafeeqChatBubbleColors.timestamp,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
