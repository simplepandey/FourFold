import 'package:flutter/material.dart';

// Static constants used in ThemeData definitions (const context only)
class AppColors {
  AppColors._();

  static const Color primary       = Color(0xFF4A7CF8);
  static const Color primaryDark   = Color(0xFF2D5BE3);
  static const Color primaryLight  = Color(0xFF6E97FF);
  static const Color green         = Color(0xFF3DD68C);
  static const Color greenDark     = Color(0xFF27B374);
  static const Color red           = Color(0xFFE74C5A);
  static const Color redDark       = Color(0xFFC0392B);
  static const Color orange        = Color(0xFFFF9500);
  static const Color orangeDark    = Color(0xFFCC7700);
  static const Color waterBlue     = Color(0xFF4A7CF8);
  static const Color waterBlueLight = Color(0xFF6E97FF);
}

// ─── Theme-aware color palette ────────────────────────────────

@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textLabel;
  final Color divider;
  final Color tankBackground;
  final Color gaugeTrack;

  // Status colors are the same in both themes
  final Color primary      = AppColors.primary;
  final Color primaryDark  = AppColors.primaryDark;
  final Color primaryLight = AppColors.primaryLight;
  final Color green        = AppColors.green;
  final Color greenDark    = AppColors.greenDark;
  final Color red          = AppColors.red;
  final Color redDark      = AppColors.redDark;
  final Color orange       = AppColors.orange;
  final Color orangeDark   = AppColors.orangeDark;
  final Color waterBlue    = AppColors.waterBlue;

  const AppColorScheme._({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textLabel,
    required this.divider,
    required this.tankBackground,
    required this.gaugeTrack,
  });

  static const dark = AppColorScheme._(
    background:      Color(0xFF080D1A),
    surface:         Color(0xFF0F1628),
    surfaceElevated: Color(0xFF162035),
    cardBorder:      Color(0xFF1E2D45),
    textPrimary:     Color(0xFFFFFFFF),
    textSecondary:   Color(0xFF8899BB),
    textMuted:       Color(0xFF4A5878),
    textLabel:       Color(0xFF6B7FA3),
    divider:         Color(0xFF1A2540),
    tankBackground:  Color(0xFF0A1020),
    gaugeTrack:      Color(0xFF1E2D45),
  );

  static const light = AppColorScheme._(
    background:      Color(0xFFF0F4FF),
    surface:         Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFE8EEF8),
    cardBorder:      Color(0xFFD0DCEE),
    textPrimary:     Color(0xFF0A1020),
    textSecondary:   Color(0xFF4A5878),
    textMuted:       Color(0xFF8899BB),
    textLabel:       Color(0xFF6B7FA3),
    divider:         Color(0xFFD0DCEE),
    tankBackground:  Color(0xFFE8EEF8),
    gaugeTrack:      Color(0xFFD0DCEE),
  );

  static AppColorScheme of(BuildContext context) =>
      Theme.of(context).extension<AppColorScheme>() ?? dark;

  @override
  AppColorScheme copyWith({
    Color? background, Color? surface, Color? surfaceElevated,
    Color? cardBorder, Color? textPrimary, Color? textSecondary,
    Color? textMuted, Color? textLabel, Color? divider,
    Color? tankBackground, Color? gaugeTrack,
  }) => AppColorScheme._(
        background:      background      ?? this.background,
        surface:         surface         ?? this.surface,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
        cardBorder:      cardBorder      ?? this.cardBorder,
        textPrimary:     textPrimary     ?? this.textPrimary,
        textSecondary:   textSecondary   ?? this.textSecondary,
        textMuted:       textMuted       ?? this.textMuted,
        textLabel:       textLabel       ?? this.textLabel,
        divider:         divider         ?? this.divider,
        tankBackground:  tankBackground  ?? this.tankBackground,
        gaugeTrack:      gaugeTrack      ?? this.gaugeTrack,
      );

  @override
  AppColorScheme lerp(AppColorScheme? other, double t) {
    if (other == null) return this;
    return AppColorScheme._(
      background:      Color.lerp(background,      other.background,      t)!,
      surface:         Color.lerp(surface,         other.surface,         t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      cardBorder:      Color.lerp(cardBorder,      other.cardBorder,      t)!,
      textPrimary:     Color.lerp(textPrimary,     other.textPrimary,     t)!,
      textSecondary:   Color.lerp(textSecondary,   other.textSecondary,   t)!,
      textMuted:       Color.lerp(textMuted,       other.textMuted,       t)!,
      textLabel:       Color.lerp(textLabel,       other.textLabel,       t)!,
      divider:         Color.lerp(divider,         other.divider,         t)!,
      tankBackground:  Color.lerp(tankBackground,  other.tankBackground,  t)!,
      gaugeTrack:      Color.lerp(gaugeTrack,      other.gaugeTrack,      t)!,
    );
  }
}

// Shorthand: final c = context.appColors;
extension AppColorsX on BuildContext {
  AppColorScheme get appColors => AppColorScheme.of(this);
}
