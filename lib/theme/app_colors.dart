import 'package:flutter/material.dart';

class AppColors {
  // Primary brand reds
  static const Color primaryRed = Color(0xFFD94F4F);
  static const Color darkRed = Color(0xFFB83535);
  static const Color accentRed = Color(0xFFFF6B6B);
  static const Color lightRed = Color(0xFFFBE9E9);

  // Backgrounds & surfaces
  static const Color backgroundLight = Color(0xFFF7F8FC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color surfaceGrey = Color(0xFFF0F1F5);

  // Text
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMedium = Color(0xFF555770);
  static const Color textGrey = Color(0xFF888AA0);
  static const Color textLight = Color(0xFFBBBDD0);

  // Semantic
  static const Color successGreen = Color(0xFF2ECC71);
  static const Color warningOrange = Color(0xFFFF9F43);
  static const Color criticalRed = Color(0xFFFF4757);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentRed, primaryRed, darkRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFD94F4F), Color(0xFF9B2335)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient softRedGradient = LinearGradient(
    colors: [Color(0xFFFFE5E5), Color(0xFFFFF0F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}