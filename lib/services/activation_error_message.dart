import 'package:dio/dio.dart';

/// Maps activation-related errors to user-facing Albanian messages.
String activationErrorMessage(Object error) {
  if (error is DioException) return _fromDio(error);
  final text = error.toString();
  if (text.contains('Empty activation response')) {
    return 'Serveri ktheu përgjigje bosh. Provoni përsëri.';
  }
  return text.replaceFirst('Exception: ', '');
}

String _fromDio(DioException e) {
  final serverMsg = _extractServerMessage(e.response?.data);
  if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;

  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Nuk mund të lidhemi me serverin. Kontrolloni lidhjen e internetit '
          'dhe URL-në e API-së.';
    case DioExceptionType.badCertificate:
      return 'Lidhja me serverin dështoi (certifikatë e pavlefshme).';
    case DioExceptionType.cancel:
      return 'Kërkesa u anulua.';
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  final status = e.response?.statusCode;
  switch (status) {
    case 400:
      return 'Të dhënat e aktivizimit nuk janë të vlefshme.';
    case 401:
      return 'Çelësi i aktivizimit ose kodi i degës është i pasaktë.';
    case 403:
      return 'Licenca është pezulluar ose ka skaduar.';
    case 404:
      return 'Çelësi i aktivizimit ose kodi i degës nuk u gjet.';
    case 409:
      return 'Kjo pajisje është tashmë e aktivizuar në një degë tjetër.';
    case 429:
      return 'Shumë përpjekje. Provoni përsëri pas pak.';
    case 500:
    case 502:
    case 503:
      return 'Gabim në server. Provoni përsëri më vonë.';
    default:
      return 'Aktivizimi dështoi (HTTP ${status ?? '—'}).';
  }
}

String? _extractServerMessage(dynamic body) {
  if (body is! Map) return null;
  final message = body['message'];
  if (message is String && message.isNotEmpty) return message;
  if (message is List) {
    return message.map((e) => e.toString()).join('\n');
  }
  return null;
}
