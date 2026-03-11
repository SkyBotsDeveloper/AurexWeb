import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../music/domain/music_models.dart';
import '../data/library_models.dart';
import '../data/library_repository.dart';

Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final repository = ref.read(libraryRepositoryProvider);
  final playlists = await repository.watchPlaylists().first;
  if (!context.mounted) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return _AddToPlaylistSheet(
        track: track,
        playlists: playlists,
        onCreatePressed: () async {
          Navigator.of(sheetContext).pop();
          final name = await _promptForPlaylistName(context);
          if (name == null || name.isEmpty) {
            return;
          }
          final playlist = await repository.createPlaylist(name);
          await repository.addTrackToPlaylist(playlist.id, track);
          if (context.mounted) {
            _showSavedSnackBar(context, playlist.name);
          }
        },
        onPlaylistPressed: (playlist) async {
          Navigator.of(sheetContext).pop();
          await repository.addTrackToPlaylist(playlist.id, track);
          if (context.mounted) {
            _showSavedSnackBar(context, playlist.name);
          }
        },
      );
    },
  );
}

void _showSavedSnackBar(BuildContext context, String playlistName) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Saved to $playlistName')),
  );
}

Future<String?> _promptForPlaylistName(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Late Night Rotation',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result?.trim();
}

class _AddToPlaylistSheet extends StatelessWidget {
  const _AddToPlaylistSheet({
    required this.track,
    required this.playlists,
    required this.onCreatePressed,
    required this.onPlaylistPressed,
  });

  final Track track;
  final List<UserPlaylist> playlists;
  final Future<void> Function() onCreatePressed;
  final Future<void> Function(UserPlaylist playlist) onPlaylistPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to Playlist',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              track.title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Create New Playlist'),
              onTap: onCreatePressed,
            ),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  'No playlists yet. Create one to start organizing tracks.',
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final playlist in playlists)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.playlist_play_rounded),
                        title: Text(playlist.name),
                        subtitle: Text('${playlist.tracks.length} tracks'),
                        onTap: () => onPlaylistPressed(playlist),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
