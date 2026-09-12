import 'package:dio/dio.dart';
import '../l10n/tr.dart';

/// Maps activation-related errors to user-facing Albanian messages.
String activationErrorMessage(Object error) {
  if (error is DioException) return _fromDio(error);
  final text = error.toString();
  if (text.contains('Empty activation response')) {
    return tr.serveriKtheuPergjigjeBoshProvoniPerseri;
  }
  return text.replaceFirst('Exception: ', '');
}

/// Maps errors from POST /licenses/request-transfer to Albanian messages.
String transferRequestErrorMessage(Object error) {
  if (error is DioException) return _fromTransferDio(error);
  return activationErrorMessage(error);
}

String _fromTransferDio(DioException e) {
  final serverMsg = _extractServerMessage(e.response?.data);
  if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;

  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return tr.nukKaLidhjeServerinKontrolloniInternetin;
    case DioExceptionType.badCertificate:
      return tr.lidhjaServerinDeshtoiCertifikatePavlefshme;
    case DioExceptionType.cancel:
      return tr.kerkesaUAnulua;
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  switch (e.response?.statusCode) {
    case 401:
    case 403:
      return tr.kerkesaNukULejuaKontaktoniAdministratorin;
    case 404:
      return tr.licencaNukUGjetKontrolloniCelesin;
    case 409:
      return tr.kerkesaEkzistonEshtePritjeAprovimit;
    default:
      return 'Kërkesa për transferim dështoi (HTTP ${e.response?.statusCode ?? '—'}).';
  }
}

String _fromDio(DioException e) {
  final serverMsg = _extractServerMessage(e.response?.data);
  if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;

  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return tr.nukMundLidhemiServerinKontrolloniLidhjen + tr.urlApi;
    case DioExceptionType.badCertificate:
      return tr.lidhjaServerinDeshtoiCertifikatePavlefshme;
    case DioExceptionType.cancel:
      return tr.kerkesaUAnulua;
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  final status = e.response?.statusCode;
  switch (status) {
    case 400:
      return tr.dhenatAktivizimitNukJaneVlefshme;
    case 401:
      return tr.celesiAktivizimitOseKodiDegesEshte;
    case 403:
      return tr.licencaEshtePezulluarOseKaSkaduar;
    case 404:
      return tr.celesiAktivizimitOseKodiDegesNuk;
    case 409:
      return tr.kjoPajisjeEshteTashmeAktivizuarDege;
    case 429:
      return tr.shumePerpjekjeProvoniPerseriPasPak;
    case 500:
    case 502:
    case 503:
      return tr.gabimServerProvoniPerseriVone;
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
