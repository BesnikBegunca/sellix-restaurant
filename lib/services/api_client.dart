import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Default NestJS API root for local development.
///
/// Override via [ApiClient.configureBaseUrl] before production use — do not
/// hardcode URLs in feature/business code.
const String kDefaultApiBaseUrl = 'http://localhost:3000/api';

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

  /// Lazily built [Dio] instance (no network I/O until a method is called).
  Dio get dio {
    _dio ??= _buildDio();
    return _dio!;
  }

  String get baseUrl => _baseUrl;

  String? get accessToken => _accessToken;

  /// Re-point the API root and reset the underlying client.
  void configureBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    _baseUrl = trimmed.endsWith('/') ? trimmed : '$trimmed/';
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
        onRequest: (options, handler) {
          final token = _accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            debugPrint('API → ${options.method} ${options.uri}');
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
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint(
              'API ✕ ${error.type} ${error.requestOptions.uri}',
            );
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
}
