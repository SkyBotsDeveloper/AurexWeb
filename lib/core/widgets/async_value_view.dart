import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final Widget? loading;
  final Widget Function(Object error, StackTrace stackTrace)? error;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          error?.call(err, stack) ??
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(err.toString(), textAlign: TextAlign.center),
            ),
          ),
    );
  }
}
