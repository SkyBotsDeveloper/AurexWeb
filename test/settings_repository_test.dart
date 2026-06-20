import 'package:aurex/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('smart cache is enabled by default and persists changes', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    expect(repository.current.smartCacheEnabled, isTrue);

    await repository.setSmartCacheEnabled(false);
    final restoredRepository = SettingsRepository(preferences);

    expect(repository.current.smartCacheEnabled, isFalse);
    expect(restoredRepository.current.smartCacheEnabled, isFalse);
  });
}
