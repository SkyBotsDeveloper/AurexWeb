import 'package:flutter_test/flutter_test.dart';

import 'package:aurex/core/utils/formatters.dart';
import 'package:aurex/features/music/domain/music_models.dart';

void main() {
  test('formatDuration formats minutes and seconds', () {
    expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '03:05');
  });

  test('music item parser covers web discovery item types', () {
    expect(MusicItemType.parse('radio_station'), MusicItemType.radio);
    expect(MusicItemType.parse('channel'), MusicItemType.channel);
    expect(MusicItemType.parse('show'), MusicItemType.show);
  });

  test(
    'aurex fallback track metadata does not persist resolved stream links',
    () {
      const song = AurexSong(
        id: 'aurex-video123',
        title: 'Online Song',
        artist: 'Online Artist',
        channel: 'Online Artist',
        duration: '4:24',
        thumbnail: 'https://i.ytimg.com/vi/video123/hqdefault.jpg',
        image: 'https://i.ytimg.com/vi/video123/hqdefault.jpg',
        videoId: 'video123',
        youtubeUrl: 'https://www.youtube.com/watch?v=video123',
      );

      final track = song.toTrack(audioUrl: 'https://stream.example/audio.mp3');
      final json = track.toJson();

      expect(track.isAurexSource, isTrue);
      expect(track.aurexVideoId, 'video123');
      expect(track.bestAudioUrl(AudioQuality.kbps160), isNotNull);
      expect(json['downloadUrl'], isEmpty);
      expect(json['source'], 'aurex');
      expect(json['externalId'], 'video123');
    },
  );
}
