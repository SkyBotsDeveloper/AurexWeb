import 'package:dio/dio.dart';

String friendlyErrorMessage(
  Object? error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error == null) {
    return fallback;
  }

  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The music source is taking too long to respond. Please try again.',
      DioExceptionType.badResponse => _httpMessage(error.response?.statusCode),
      DioExceptionType.cancel => 'The request was cancelled.',
      DioExceptionType.connectionError =>
        'Check your internet connection and try again.',
      DioExceptionType.badCertificate =>
        'A secure connection could not be verified.',
      DioExceptionType.unknown =>
        'The music source could not be reached right now.',
    };
  }

  final raw = error.toString().toLowerCase();
  if (raw.contains('auth') ||
      raw.contains('invalid login') ||
      raw.contains('email') ||
      raw.contains('password')) {
    return 'The account action could not be completed. Check the details and try again.';
  }
  if (raw.contains('permission') ||
      raw.contains('policy') ||
      raw.contains('unauthorized') ||
      raw.contains('forbidden')) {
    return 'You do not have permission to do that.';
  }
  if (raw.contains('network') ||
      raw.contains('socket') ||
      raw.contains('connection')) {
    return 'Check your internet connection and try again.';
  }
  if (raw.contains('timeout') || raw.contains('timed out')) {
    return 'This is taking too long. Please try again.';
  }

  return fallback;
}

String _httpMessage(int? statusCode) {
  if (statusCode == null) {
    return 'The music source returned an unexpected response.';
  }
  if (statusCode == 404) {
    return 'This item is no longer available.';
  }
  if (statusCode == 429) {
    return 'Too many requests right now. Please wait a moment and try again.';
  }
  if (statusCode >= 500) {
    return 'The music source is having trouble right now. Please try again.';
  }
  return 'This request could not be completed. Please try again.';
}
