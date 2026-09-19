import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

typedef _CryptProtectNative = Int32 Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Utf16> szDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<_DataBlob> pDataOut,
);
typedef _CryptProtectDart = int Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Utf16> szDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<_DataBlob> pDataOut,
);

typedef _LocalFreeNative = Pointer<Void> Function(Pointer<Void> hMem);
typedef _LocalFreeDart = Pointer<Void> Function(Pointer<Void> hMem);

/// Windows DPAPI (`CryptProtectData`) via Dart FFI — no ATL / native plugin.
class WindowsDpapi {
  WindowsDpapi._();

  static bool get isAvailable => Platform.isWindows;

  static bool _loaded = false;
  static late final _CryptProtectDart _protect;
  static late final _CryptProtectDart _unprotect;
  static late final _LocalFreeDart _localFree;

  static void _ensureLoaded() {
    if (_loaded) return;
    if (!Platform.isWindows) {
      throw UnsupportedError('DPAPI is Windows-only');
    }
    final crypt32 = DynamicLibrary.open('crypt32.dll');
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    _protect = crypt32.lookupFunction<_CryptProtectNative, _CryptProtectDart>(
      'CryptProtectData',
    );
    _unprotect = crypt32.lookupFunction<_CryptProtectNative, _CryptProtectDart>(
      'CryptUnprotectData',
    );
    _localFree = kernel32.lookupFunction<_LocalFreeNative, _LocalFreeDart>(
      'LocalFree',
    );
    _loaded = true;
  }

  static Uint8List protect(Uint8List plaintext) {
    _ensureLoaded();
    return _crypt(plaintext, protect: true);
  }

  static Uint8List unprotect(Uint8List ciphertext) {
    _ensureLoaded();
    return _crypt(ciphertext, protect: false);
  }

  static Uint8List _crypt(Uint8List data, {required bool protect}) {
    final input = calloc<_DataBlob>();
    final output = calloc<_DataBlob>();
    final inputBytes = calloc<Uint8>(data.length);
    try {
      inputBytes.asTypedList(data.length).setAll(0, data);
      input.ref.cbData = data.length;
      input.ref.pbData = inputBytes;

      final ok = (protect ? _protect : _unprotect)(
        input,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        0,
        output,
      );
      if (ok == 0) {
        throw StateError(
          protect ? 'CryptProtectData failed' : 'CryptUnprotectData failed',
        );
      }
      final outLen = output.ref.cbData;
      final outPtr = output.ref.pbData;
      final bytes = Uint8List.fromList(outPtr.asTypedList(outLen));
      if (outPtr != nullptr) {
        _localFree(outPtr.cast());
      }
      return bytes;
    } finally {
      calloc.free(inputBytes);
      calloc.free(input);
      calloc.free(output);
    }
  }
}
