import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class AurexScrollBehavior extends MaterialScrollBehavior {
  const AurexScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final platform = getPlatform(context);
    final width = MediaQuery.sizeOf(context).width;
    final desktopLike =
        kIsWeb ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;

    if (!desktopLike) {
      return child;
    }

    final isHorizontal =
        details.direction == AxisDirection.left ||
        details.direction == AxisDirection.right;
    if (isHorizontal) {
      return child;
    }

    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      trackVisibility: false,
      interactive: true,
      thickness: width < 720 ? 4.5 : 5.5,
      radius: const Radius.circular(999),
      child: child,
    );
  }
}
