import 'package:flutter_test/flutter_test.dart';

import 'package:aurex/core/utils/formatters.dart';

void main() {
  test('formatDuration formats minutes and seconds', () {
    expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '03:05');
  });
}
