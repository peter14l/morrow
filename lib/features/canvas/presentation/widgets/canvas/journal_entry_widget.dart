import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class JournalEntryWidget extends StatelessWidget {
  final String content;
  final DateTime createdAt;

  const JournalEntryWidget({
    super.key,
    required this.content,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCF0), // Creamy paper color
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(createdAt).toUpperCase(),
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: Colors.brown[300],
                ),
              ),
              Icon(Icons.edit_note, color: Colors.brown[100], size: 20),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            content,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              height: 1.6,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(width: 40, height: 1, color: Colors.brown[100]),
          ),
        ],
      ),
    );
  }
}
