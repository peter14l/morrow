import 'package:flutter/material.dart';

class OasisColors {
  static const deep = Color(0xFF0C0F14); // premium deep dark blue-black
  static const moss = Color(0xFF141A28); // dark slate/card surface
  static const glow = Color(0xFF6366F1); // indigo accent/CTA
  static const sage = Color(0xFF2E3B52); // slate borders/dividers
  static const sand = Color(0xFFF1F5F9); // light cool display headings
  static const mist = Color(0xFF94A3B8); // cool grey secondary text
  static const white = Color(0xFFFFFFFF); // pure text / highlights
  static const deepTransparent = Color(0x800B0F19); // glass overlays

  // Opacity variants for Glassmorphism
  static Color glassBackground = deep.withValues(alpha: 0.6);
  static Color glassBorder = glow.withValues(alpha: 0.1);
}
