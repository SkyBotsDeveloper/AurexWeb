import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'glass_panel.dart';

class ScreenIntroPanel extends StatelessWidget {
  const ScreenIntroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.trailing,
    this.actions = const <Widget>[],
    this.footer,
    this.compact = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget? trailing;
  final List<Widget> actions;
  final Widget? footer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final theme = Theme.of(context);

    return GlassPanel(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    eyebrow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 420 : 680),
            child: Text(
              title,
              style: compact
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 520 : 760),
            child: Text(
              description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
          if (footer != null) ...[const SizedBox(height: 16), footer!],
        ],
      ),
    );
  }
}
