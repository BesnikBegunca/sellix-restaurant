import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Debug-only logging for activation endpoints (never logs tokens).
void logActivationRequest({
  required String endpoint,
  required Set<String> bodyKeys,
}) {
  if (!kDebugMode) return;
  debugPrint(
    'Activation API →\n'
    '  baseUrl=${ApiClient.instance.baseUrl}\n'
    '  endpoint=$endpoint\n'
    '  bodyKeys=${bodyKeys.join(', ')}',
  );
}

void logActivationResponse(Response<dynamic> response) {
  if (!kDebugMode) return;
  debugPrint(
    'Activation API ←\n'
    '  status=${response.statusCode}\n'
    '  body=${_sanitizeForLog(response.data)}',
  );
}

void logActivationError(DioException error) {
  if (!kDebugMode) return;
  debugPrint(
    'Activation API ✕\n'
    '  baseUrl=${error.requestOptions.baseUrl}\n'
    '  endpoint=${error.requestOptions.path}\n'
    '  status=${error.response?.statusCode}\n'
    '  body=${_sanitizeForLog(error.response?.data)}',
  );
}

dynamic _sanitizeForLog(dynamic data) {
  if (data is! Map) return data;
  final copy = Map<String, dynamic>.from(data);
  for (final key in ['accessToken', 'refreshToken']) {
    if (copy.containsKey(key)) copy[key] = '<redacted>';
  }
  return copy;
}
