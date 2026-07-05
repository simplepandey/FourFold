import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ButtonVariant { primary, secondary, danger, ghost }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final ButtonVariant variant;
  final bool isLoading;
  final Widget? leading;
  final double? height;

  const CustomButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
    this.leading,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final (bgColor, textColor, borderColor) = switch (variant) {
      ButtonVariant.primary  => (c.primary,          Colors.white,   Colors.transparent),
      ButtonVariant.secondary => (c.surfaceElevated, c.textPrimary,  c.cardBorder),
      ButtonVariant.danger   => (c.redDark.withValues(alpha: 0.2), c.red, c.red.withValues(alpha: 0.4)),
      ButtonVariant.ghost    => (Colors.transparent,  c.textSecondary, c.cardBorder),
    };

    return SizedBox(
      width: double.infinity,
      height: height ?? 54,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: textColor,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: 8)],
                      Text(
                        label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
