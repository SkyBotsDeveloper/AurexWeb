import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blurSigma = 16,
    this.tintColor,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint =
        tintColor ??
        (isDark
            ? palette.surfaceElevated.withAlpha(138)
            : Colors.white.withAlpha(152));
    final borderColor = isDark
        ? Colors.white.withAlpha(52)
        : Colors.white.withAlpha(232);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withAlpha(isDark ? 120 : 48),
              blurRadius: 34,
              spreadRadius: -10,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: palette.accent.withAlpha(isDark ? 30 : 18),
              blurRadius: 30,
              spreadRadius: -16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: borderRadius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withAlpha(isDark ? 34 : 116),
                          tint.withAlpha(isDark ? 120 : 142),
                          palette.accentStrong.withAlpha(isDark ? 16 : 10),
                          Colors.black.withAlpha(isDark ? 18 : 0),
                        ],
                        stops: const [0, 0.38, 0.72, 1],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.08),
                        radius: 1.08,
                        colors: [
                          Colors.white.withAlpha(isDark ? 14 : 54),
                          Colors.white.withAlpha(0),
                          Colors.black.withAlpha(isDark ? 34 : 0),
                        ],
                        stops: const [0, 0.58, 1],
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(color: borderColor),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 1,
                  height: 1.4,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(0),
                            Colors.white.withAlpha(isDark ? 116 : 200),
                            Colors.white.withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 1,
                  height: 1,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(0),
                            palette.accent.withAlpha(isDark ? 34 : 24),
                            Colors.white.withAlpha(0),
                          ],
                        ),
                      ),
                    ),
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
