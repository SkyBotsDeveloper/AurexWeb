import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NetworkArtwork extends StatelessWidget {
  const NetworkArtwork({
    super.key,
    required this.imageUrl,
    this.fallbackIcon = Icons.music_note_rounded,
    this.fit = BoxFit.cover,
    this.iconSize = 34,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _ArtworkFallback(icon: fallbackIcon, iconSize: iconSize);
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholderFadeInDuration: const Duration(milliseconds: 140),
      placeholder: (context, _) =>
          _ArtworkFallback(icon: fallbackIcon, iconSize: iconSize),
      errorWidget: (context, _, _) =>
          _ArtworkFallback(icon: fallbackIcon, iconSize: iconSize),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.icon, required this.iconSize});

  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return ColoredBox(
      color: palette.surfaceBright,
      child: Center(
        child: Icon(icon, color: palette.accent, size: iconSize),
      ),
    );
  }
}
