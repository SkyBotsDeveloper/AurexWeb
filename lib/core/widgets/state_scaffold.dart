import 'package:flutter/material.dart';

import 'glass_panel.dart';
import '../theme/app_colors.dart';

class StateScaffold extends StatelessWidget {
  const StateScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        palette.accentSoft,
                        palette.background.withAlpha(24),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: palette.border),
                    boxShadow: [
                      BoxShadow(
                        color: palette.glow,
                        blurRadius: 32,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: palette.accent, size: 34),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (action != null) ...[const SizedBox(height: 20), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
