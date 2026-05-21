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
}
