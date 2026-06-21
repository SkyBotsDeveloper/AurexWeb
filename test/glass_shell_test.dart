import 'package:aurex/core/widgets/app_bottom_nav.dart';
import 'package:aurex/core/widgets/app_shell_scope.dart';
import 'package:aurex/core/widgets/frosted_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('frosted shell uses a real backdrop filter and shared inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: AppShellScope(
            bottomContentInset: 184,
            child: Scaffold(
              body: Builder(
                builder: (context) => Stack(
                  children: [
                    Text(
                      '${AppShellScope.bottomInsetOf(context)}',
                      textDirection: TextDirection.ltr,
                    ),
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: FrostedGlass(
                        child: SizedBox(width: 280, height: 72),
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

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('184.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation stays usable at 360 logical pixels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var selectedIndex = -1;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: FrostedGlass(
                  child: AppBottomNav(
                    currentIndex: 0,
                    embedded: true,
                    onTap: (index) => selectedIndex = index,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pump();
    expect(selectedIndex, 1);
  });

  testWidgets('floating navigation remains capped on a wide viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: FrostedGlass(
                  child: AppBottomNav(
                    currentIndex: 3,
                    embedded: true,
                    onTap: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final glassSize = tester.getSize(find.byType(FrostedGlass));
    expect(glassSize.width, lessThanOrEqualTo(720));
    expect(tester.takeException(), isNull);
  });
}
