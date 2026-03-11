import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/music/domain/music_models.dart';
import '../theme/app_colors.dart';

class ArtworkCard extends StatelessWidget {
  const ArtworkCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 172,
    this.height = 232,
  });

  final MediaSummary item;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.tileTop, palette.tileBottom],
              ),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withAlpha(60),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
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
                          child: ColoredBox(
                            color: palette.surfaceBright,
                            child: item.artworkUrl == null
                                ? Icon(
                                    Icons.music_note,
                                    color: palette.accent,
                                    size: 38,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: item.artworkUrl!,
                                    fit: BoxFit.cover,
                                  ),
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
                            _typeLabel(item.type),
                            style: Theme.of(context).textTheme.bodyMedium
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
                            _actionIcon(item.type),
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
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.artistText ??
                            item.subtitle ??
                            item.description ??
                            _typeLabel(item.type),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
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
      _ => 'Listen',
    };
  }

  static IconData _actionIcon(MusicItemType type) {
    return switch (type) {
      MusicItemType.song => Icons.play_arrow_rounded,
      MusicItemType.album => Icons.album_rounded,
      MusicItemType.artist => Icons.person_rounded,
      MusicItemType.playlist => Icons.queue_music_rounded,
      _ => Icons.arrow_forward_rounded,
    };
  }
}
