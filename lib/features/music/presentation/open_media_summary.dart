import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../player/data/playback_controller.dart';
import '../../rooms/data/room_session_controller.dart';
import '../data/music_repository.dart';
import '../domain/music_models.dart';

Future<void> openMediaSummary(
  BuildContext context,
  WidgetRef ref,
  MediaSummary item,
) async {
  try {
    switch (item.type) {
      case MusicItemType.song:
        final roomSession = ref.read(roomSessionControllerProvider);
        if (roomSession.controlsLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(roomPlaybackLockedMessage(roomSession))),
          );
          return;
        }
        final track = await ref.read(musicRepositoryProvider).fetchSong(item.id);
        await ref.read(playbackControllerProvider).playTrack(track);
        return;
      case MusicItemType.album:
        if (context.mounted) {
          context.push('/album/${item.id}');
        }
        return;
      case MusicItemType.playlist:
        if (context.mounted) {
          context.push('/playlist/${item.id}');
        }
        return;
      case MusicItemType.artist:
        if (context.mounted) {
          context.push('/artist/${item.id}');
        }
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This item is not playable yet.')),
        );
        return;
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}
