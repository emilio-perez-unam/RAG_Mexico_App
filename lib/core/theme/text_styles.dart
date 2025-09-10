import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTextStyles {
  static const String fontFamily = 'Open Sans';

  static const TextStyle heading1 = TextStyle(
    color: AppColors.primaryBlue,
    fontSize: 20,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    height: 1.40,
  );

  static const TextStyle heading2 = TextStyle(
    color: AppColors.primaryGreen,
    fontSize: 18,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    height: 1.56,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    height: 1.50,
  );

  static const TextStyle bodyBold = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    height: 1.50,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    height: 1.33,
  );

  static const TextStyle button = TextStyle(
    color: AppColors.white,
    fontSize: 16,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle link = TextStyle(
    color: AppColors.primaryBlue,
    fontSize: 14,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    height: 1.43,
  );

  static const TextStyle citation = TextStyle(
    color: AppColors.primaryBlue,
    fontSize: 16,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    height: 1.50,
  );
}
