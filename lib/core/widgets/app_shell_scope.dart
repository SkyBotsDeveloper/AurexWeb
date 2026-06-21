import 'package:flutter/widgets.dart';

class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.bottomContentInset,
    required super.child,
  });

  final double bottomContentInset;

  static double bottomInsetOf(BuildContext context, {double fallback = 24}) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppShellScope>();
    final inset = scope?.bottomContentInset ?? 0;
    return inset > fallback ? inset : fallback;
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      bottomContentInset != oldWidget.bottomContentInset;
}
