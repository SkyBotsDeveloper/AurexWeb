import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/music/domain/music_models.dart';
import '../theme/app_colors.dart';
import 'network_artwork.dart';
import 'skeleton_loader.dart';

class ArtworkCard extends StatefulWidget {
  const ArtworkCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 172,
    this.height = 232,
  });

  final MediaSummary item;
  final FutureOr<void> Function() onTap;
  final double width;
  final double height;

  @override
  State<ArtworkCard> createState() => _ArtworkCardState();
}

class _ArtworkCardState extends State<ArtworkCard> {
  bool _busy = false;
  bool _hovered = false;

  Future<void> _handleTap() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final startedAt = DateTime.now();
    try {
      await Future<void>.sync(widget.onTap);
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = const Duration(milliseconds: 360) - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) {
          setState(() => _hovered = true);
        }
      },
      onExit: (_) {
        if (_hovered) {
          setState(() => _hovered = false);
        }
      },
      child: AnimatedScale(
        scale: _hovered && !_busy ? 1.025 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _busy ? null : _handleTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [palette.tileTop, palette.tileBottom],
                  ),
                  border: Border.all(
                    color: _hovered ? palette.accentSoft : palette.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withAlpha(_hovered ? 95 : 60),
                      blurRadius: _hovered ? 30 : 24,
                      offset: Offset(0, _hovered ? 18 : 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                  child: NetworkArtwork(
                                    imageUrl: widget.item.artworkUrl,
                                    cleanArtworkQuery: widget.item.title,
                                    cleanArtworkType: widget.item.type.name,
                                    cleanArtworkSubtitle:
                                        widget.item.artistText ??
                                        widget.item.description ??
                                        widget.item.subtitle,
                                    fallbackIcon: Icons.music_note_rounded,
                                    iconSize: 38,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        palette.background.withAlpha(136),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 12,
                                top: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.background.withAlpha(180),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: palette.border),
                                  ),
                                  child: Text(
                                    _typeLabel(widget.item.type),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: palette.textPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: palette.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _actionIcon(widget.item.type),
                                    color: palette.background,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.item.artistText ??
                                    widget.item.subtitle ??
                                    widget.item.description ??
                                    _typeLabel(widget.item.type),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_busy)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: palette.background.withAlpha(170),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 84,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SkeletonBlock(width: 54, height: 54),
                                    SizedBox(height: 12),
                                    SkeletonBlock(width: 84, height: 12),
                                  ],
                                ),
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
        ),
      ),
    );
  }

  String _typeLabel(MusicItemType type) {
    return switch (type) {
      MusicItemType.song => 'Song',
      MusicItemType.album => 'Album',
      MusicItemType.artist => 'Artist',
      MusicItemType.playlist => 'Playlist',
      MusicItemType.radio => 'Radio',
      MusicItemType.channel => 'Category',
      MusicItemType.podcast || MusicItemType.show => 'Show',
      _ => 'Listen',
    };
  }

  static IconData _actionIcon(MusicItemType type) {
    return switch (type) {
      MusicItemType.song => Icons.play_arrow_rounded,
      MusicItemType.album => Icons.album_rounded,
      MusicItemType.artist => Icons.person_rounded,
      MusicItemType.playlist => Icons.queue_music_rounded,
      MusicItemType.radio => Icons.radio_rounded,
      MusicItemType.channel => Icons.category_rounded,
      MusicItemType.podcast || MusicItemType.show => Icons.podcasts_rounded,
      _ => Icons.arrow_forward_rounded,
    };
  }
}
