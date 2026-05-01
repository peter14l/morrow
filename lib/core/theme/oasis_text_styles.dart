import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'oasis_colors.dart';

class OasisTextStyles {
  static TextStyle onboardingHeadline = GoogleFonts.cormorantGaramond(
    fontSize: 38,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    color: OasisColors.sand,
    height: 1.15,
  );

  static TextStyle onboardingSubtitle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: OasisColors.mist,
    height: 1.6,
  );

  static TextStyle ctaLabel = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: OasisColors.deep,
    letterSpacing: 0.3,
  );
}
