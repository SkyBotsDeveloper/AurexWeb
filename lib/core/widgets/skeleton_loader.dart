import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'glass_panel.dart';

class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
    this.margin,
  });

  final double? width;
  final double height;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? palette.surfaceInset : palette.surfaceMuted;
    final highlight = isDark ? palette.surfaceBright : palette.surfaceElevated;
    final radius = widget.borderRadius ?? BorderRadius.circular(14);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerOffset = (_controller.value * 2.4) - 1.2;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(shimmerOffset - 1, 0),
              end: Alignment(shimmerOffset + 1, 0),
              colors: [base, highlight, base],
              stops: const [0.2, 0.5, 0.8],
            ),
          ),
        );
      },
    );
  }
}

class MediaDetailSkeleton extends StatelessWidget {
  const MediaDetailSkeleton({
    super.key,
    this.rowCount = 6,
    this.showDescription = true,
  });

  final int rowCount;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.sizeOf(context).width >= 1120
        ? 32.0
        : 140.0;

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 18,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SkeletonBlock(
                width: 144,
                height: 144,
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBlock(width: 78, height: 28),
                    SizedBox(height: 14),
                    SkeletonBlock(width: 300, height: 34),
                    SizedBox(height: 10),
                    SkeletonBlock(width: 420, height: 16),
                    SizedBox(height: 8),
                    SkeletonBlock(width: 260, height: 16),
                    SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SkeletonBlock(width: 116, height: 50),
                        SizedBox(width: 10),
                        SkeletonBlock(width: 126, height: 50),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDescription) ...[
          const SizedBox(height: 18),
          const GlassPanel(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: double.infinity, height: 14),
                SizedBox(height: 10),
                SkeletonBlock(width: double.infinity, height: 14),
                SizedBox(height: 10),
                SkeletonBlock(width: 280, height: 14),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBlock(width: 128, height: 24),
              const SizedBox(height: 18),
              for (var index = 0; index < rowCount; index++) ...[
                const _SkeletonListRow(),
                if (index < rowCount - 1) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonListRow extends StatelessWidget {
  const _SkeletonListRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBlock(
          width: 54,
          height: 54,
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBlock(width: double.infinity, height: 16),
              SizedBox(height: 8),
              SkeletonBlock(width: 180, height: 14),
            ],
          ),
        ),
        SizedBox(width: 14),
        SkeletonBlock(
          width: 36,
          height: 36,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ],
    );
  }
}

class MediaRailSkeleton extends StatelessWidget {
  const MediaRailSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final imageHeight = compact ? 150.0 : 170.0;
    return SizedBox(
      height: compact ? 212 : 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) => SizedBox(
          width: compact ? 148 : 172,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBlock(
                width: double.infinity,
                height: imageHeight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              const SizedBox(height: 12),
              const SkeletonBlock(width: double.infinity, height: 18),
              const SizedBox(height: 8),
              const SkeletonBlock(width: 110, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultsListSkeleton extends StatelessWidget {
  const ResultsListSkeleton({
    super.key,
    this.groupCount = 3,
    this.rowCount = 4,
  });

  final int groupCount;
  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var group = 0; group < groupCount; group++) ...[
          SkeletonBlock(width: group == 0 ? 210 : 150, height: 24),
          const SizedBox(height: 12),
          GlassPanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                for (var index = 0; index < rowCount; index++) ...[
                  const _SkeletonListRow(),
                  if (index < rowCount - 1) const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}
