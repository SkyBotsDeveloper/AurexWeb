import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: palette.backgroundGradient),
          ),
        ),
        Positioned(
          top: -120,
          left: -80,
          child: IgnorePointer(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [palette.ambientTopGlow, Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: -120,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [palette.ambientRightGlow, Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          left: 40,
          child: IgnorePointer(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [palette.ambientBottomGlow, Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
