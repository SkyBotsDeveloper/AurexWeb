import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(24);

    final panelDecoration = BoxDecoration(
      color: isDark ? palette.surfaceElevated : null,
      gradient: isDark ? null : palette.panelGradient,
      borderRadius: radius,
      border: Border.all(color: palette.border.withAlpha(isDark ? 170 : 220)),
      boxShadow: [
        BoxShadow(
          color: palette.shadow.withAlpha(isDark ? 56 : 80),
          blurRadius: isDark ? 18 : 28,
          offset: Offset(0, isDark ? 10 : 16),
        ),
        if (!isDark)
          BoxShadow(
            color: palette.glow,
            blurRadius: 32,
            offset: Offset(0, 12),
            spreadRadius: -24,
          ),
      ],
    );

    return Container(
      margin: margin,
      padding: padding,
      decoration: panelDecoration,
      child: isDark
          ? child
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x18FFFFFF), Colors.transparent],
                ),
              ),
              child: child,
            ),
    );
  }
}
