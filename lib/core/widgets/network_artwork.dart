import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/clean_artwork_resolver.dart';
import '../theme/app_colors.dart';

class NetworkArtwork extends StatelessWidget {
  const NetworkArtwork({
    super.key,
    required this.imageUrl,
    this.fallbackIcon = Icons.music_note_rounded,
    this.fit = BoxFit.cover,
    this.iconSize = 34,
    this.cleanArtworkQuery,
    this.cleanArtworkType,
    this.cleanArtworkSubtitle,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final BoxFit fit;
  final double iconSize;
  final String? cleanArtworkQuery;
  final String? cleanArtworkType;
  final String? cleanArtworkSubtitle;

  @override
  Widget build(BuildContext context) {
    final rawUrl = imageUrl?.trim();
    final shouldBlockRawUrl = isCorsProneArtworkUrl(rawUrl);
    final url = shouldBlockRawUrl ? null : rawUrl;
    final query = cleanArtworkQuery?.trim();
    final canResolveCleanArtwork =
        query != null &&
        query.isNotEmpty &&
        (shouldBlockRawUrl ||
            (url != null && url.isNotEmpty && _shouldResolveCleanArtwork(url)));

    if (canResolveCleanArtwork) {
      return FutureBuilder<String?>(
        future: CleanArtworkResolver.resolve(
          query: query,
          type: cleanArtworkType,
          subtitle: cleanArtworkSubtitle,
        ),
        builder: (context, snapshot) {
          final resolvedUrl = snapshot.data?.trim();
          if (resolvedUrl != null &&
              resolvedUrl.isNotEmpty &&
              !isCorsProneArtworkUrl(resolvedUrl)) {
            return _ArtworkImage(
              imageUrl: resolvedUrl,
              fit: fit,
              fallbackIcon: fallbackIcon,
              iconSize: iconSize,
            );
          }
          if (url == null || url.isEmpty) {
            return _ArtworkFallback(icon: fallbackIcon, iconSize: iconSize);
          }
          return _ArtworkImage(
            imageUrl: url,
            fit: fit,
            fallbackIcon: fallbackIcon,
            iconSize: iconSize,
          );
        },
      );
    }

    if (url == null || url.isEmpty) {
      return _ArtworkFallback(icon: fallbackIcon, iconSize: iconSize);
    }

    return _ArtworkImage(
      imageUrl: url,
      fit: fit,
      fallbackIcon: fallbackIcon,
      iconSize: iconSize,
    );
  }

  bool _shouldResolveCleanArtwork(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('saavncdn.com') || host.contains('jiosaavn.com');
  }
}

bool isCorsProneArtworkUrl(String? rawUrl) {
  final url = rawUrl?.trim();
  if (url == null || url.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(url);
  final host = uri?.host.toLowerCase() ?? '';
  final path = uri?.path.toLowerCase() ?? '';
  final isSaavnHost =
      host == 'jiosaavn.com' ||
      host.endsWith('.jiosaavn.com') ||
      host == 'saavncdn.com' ||
      host.endsWith('.saavncdn.com');
  if (!isSaavnHost) {
    return false;
  }

  return path.contains('artist-default') ||
      path.contains('share-image') ||
      path.contains('/_i/');
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({
    required this.imageUrl,
    required this.fit,
    required this.fallbackIcon,
    required this.iconSize,
  });

  final String imageUrl;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholderFadeInDuration: const Duration(milliseconds: 140),
      imageBuilder: (context, imageProvider) => _CroppedArtworkImage(
        imageProvider: imageProvider,
        fit: fit,
        cropScale: _cropScaleFor(imageUrl),
      ),
      placeholder: (context, _) =>
          _ArtworkFallback(icon: fallbackIcon, iconSize: iconSize),
      errorWidget: (context, _, _) =>
          _ArtworkFallback(icon: fallbackIcon, iconSize: iconSize),
    );
  }

  double _cropScaleFor(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('saavncdn.com') ? 1.12 : 1;
  }
}

class _CroppedArtworkImage extends StatelessWidget {
  const _CroppedArtworkImage({
    required this.imageProvider,
    required this.fit,
    required this.cropScale,
  });

  final ImageProvider imageProvider;
  final BoxFit fit;
  final double cropScale;

  @override
  Widget build(BuildContext context) {
    final image = SizedBox.expand(
      child: Image(image: imageProvider, fit: fit),
    );
    if (cropScale == 1) {
      return image;
    }
    return ClipRect(
      child: Transform.scale(scale: cropScale, child: image),
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
