import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';
import 'secure_activation_token_store.dart';

/// Fallback NestJS API root used when no config file or env var is present.
///
/// At startup [RuntimeConfigService.load] resolves the real URL and passes it
/// to [ApiClient.configureBaseUrl] — do not hardcode URLs in feature code.
const String kDefaultApiBaseUrl = 'http://127.0.0.1:3000';

/// Shared HTTP client for future NestJS sync and auth (no feature calls yet).
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  Dio? _dio;
  String _baseUrl = kDefaultApiBaseUrl;
  String? _accessToken;

  /// Set from [main] to handle 401 device revocation without circular imports.
  Future<void> Function(DioException error)? onUnauthorizedRevoke;

  /// Lazily built [Dio] instance (no network I/O until a method is called).
  Dio get dio {
    _dio ??= _buildDio();
    return _dio!;
  }

  String get baseUrl => _baseUrl;

  String? get accessToken => _accessToken;

  /// Re-point the API root and reset the underlying client.
  ///
  /// Strips any trailing slash so that paths like `/activation/desktop` can
  /// be concatenated cleanly by Dio.
  void configureBaseUrl(String baseUrl) {
    _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _resetClient();
  }

  void setAccessToken(String token) {
    _accessToken = token;
  }

  void clearAccessToken() {
    _accessToken = null;
  }

  void _resetClient() {
    _dio?.close(force: true);
    _dio = null;
  }

  Dio _buildDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        headers: {
          Headers.acceptHeader: 'application/json',
          Headers.contentTypeHeader: 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );

    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureActivationTokenStore.instance
              .readAccessToken();
          if (token != null &&
              token.isNotEmpty &&
              !options.headers.containsKey('Authorization')) {
            options.headers['authorization'] = 'Bearer $token';
            options.headers['Authorization'] = 'Bearer $token';
            _accessToken = token;
          }
          if (kDebugMode) {
            debugPrint(
              'API REQUEST:\n'
              '  baseUrl=${options.baseUrl}\n'
              '  path=${options.path}\n'
              '  full=${options.uri}',
            );
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              'API ← ${response.statusCode} ${response.requestOptions.uri}',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            if (error.type == DioExceptionType.connectionError) {
              final online = ConnectivityService.instance.isOnline;
              debugPrint(
                'API CONNECTION ERROR:\n'
                '  baseUrl=${error.requestOptions.baseUrl}\n'
                '  type=${error.type}\n'
                '  message=${error.message}\n'
                '  connectivity=${online ? "online" : "offline"}',
              );
            } else {
              debugPrint('API ✕ ${error.type} ${error.requestOptions.uri}');
            }
          }

          final revokeHandler = onUnauthorizedRevoke;
          if (revokeHandler != null) {
            await revokeHandler(error);
          }

          handler.next(error);
        },
      ),
    );

    return client;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
