import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF003366);
  static const Color primaryGreen = Color(0xFF006847);

  // Status Colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFDC143C);

  // Neutral Colors
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color backgroundGray = Color(0xFFF5F5F5);
  static const Color white = Colors.white;

  // Shadow
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 6,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 4,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];
}
