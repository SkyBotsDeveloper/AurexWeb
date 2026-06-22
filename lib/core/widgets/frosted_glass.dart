import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blurSigma = 10,
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
            ? palette.surfaceElevated.withAlpha(72)
            : Colors.white.withAlpha(108));
    final borderColor = isDark
        ? Colors.white.withAlpha(42)
        : Colors.white.withAlpha(210);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withAlpha(isDark ? 110 : 44),
              blurRadius: 44,
              spreadRadius: -15,
              offset: const Offset(0, 23),
            ),
            BoxShadow(
              color: palette.accent.withAlpha(isDark ? 24 : 16),
              blurRadius: 34,
              spreadRadius: -21,
              offset: const Offset(0, 12),
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
                          Colors.white.withAlpha(isDark ? 34 : 110),
                          tint.withAlpha(isDark ? 52 : 92),
                          palette.accentStrong.withAlpha(isDark ? 20 : 12),
                          Colors.black.withAlpha(isDark ? 8 : 0),
                        ],
                        stops: const [0, 0.32, 0.76, 1],
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
                          Colors.white.withAlpha(isDark ? 18 : 54),
                          Colors.white.withAlpha(0),
                          Colors.black.withAlpha(isDark ? 8 : 0),
                        ],
                        stops: const [0, 0.7, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 24,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(isDark ? 58 : 120),
                            palette.accentStrong.withAlpha(isDark ? 20 : 10),
                            Colors.white.withAlpha(0),
                          ],
                          stops: const [0, 0.34, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 24,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            Colors.white.withAlpha(isDark ? 44 : 104),
                            palette.accent.withAlpha(isDark ? 18 : 9),
                            Colors.white.withAlpha(0),
                          ],
                          stops: const [0, 0.34, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        gradient: RadialGradient(
                          center: const Alignment(0, 0.08),
                          radius: 0.92,
                          colors: [
                            Colors.white.withAlpha(0),
                            Colors.white.withAlpha(0),
                            Colors.black.withAlpha(isDark ? 16 : 0),
                          ],
                          stops: const [0, 0.76, 1],
                        ),
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
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withAlpha(isDark ? 28 : 74),
                            Colors.white.withAlpha(0),
                            Colors.black.withAlpha(isDark ? 12 : 0),
                          ],
                          stops: const [0, 0.34, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(color: borderColor, width: 0.9),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 1,
                  height: 2.2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(0),
                            Colors.white.withAlpha(isDark ? 188 : 232),
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
