// Static text styles without colors — apply color via TextStyle.copyWith(color: context.appColors.X)
import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle displayLarge  = TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const TextStyle displayMedium = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.3);
  static const TextStyle headingLarge  = TextStyle(fontSize: 22, fontWeight: FontWeight.w700);
  static const TextStyle headingMedium = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
  static const TextStyle headingSmall  = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  static const TextStyle bodyLarge     = TextStyle(fontSize: 15, fontWeight: FontWeight.w400);
  static const TextStyle bodyMedium    = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
  static const TextStyle bodySmall     = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
  static const TextStyle label         = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2);
  static const TextStyle buttonText    = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3);
}
