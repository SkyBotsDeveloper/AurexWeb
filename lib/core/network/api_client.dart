import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_providers.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final env = ref.watch(appEnvProvider);
  final logger = ref.watch(appLoggerProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: env.musicApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kDebugMode) {
          logger.d('HTTP ${options.method} ${options.uri}');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        logger.e(
          'HTTP ${error.requestOptions.method} ${error.requestOptions.uri}',
          error: error.message,
          stackTrace: error.stackTrace,
        );
        handler.next(error);
      },
    ),
  );

  return dio;
});
