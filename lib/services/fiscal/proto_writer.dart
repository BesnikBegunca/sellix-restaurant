import 'dart:convert';
import 'dart:typed_data';

/// Minimal proto3 wire-format writer.
///
/// The fiscalization service (ATK) accepts the protobuf serialization of
/// `models.proto`. Rather than pulling in `protoc` and generated code, this
/// writes the handful of field types those two messages use.
///
/// Proto3 semantics that matter here:
///  * default values (0, "", empty list) are **not** written — the reference
///    payloads from ATK omit them, and the signature is computed over the
///    exact bytes, so writing them would break verification;
///  * `int64`/`uint64` use varint, `float` uses a 32-bit little-endian field,
///    strings and nested messages are length-delimited.
class ProtoWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  Uint8List toBytes() => _out.toBytes();

  static const int _wireVarint = 0;
  static const int _wireFixed32 = 5;
  static const int _wireLengthDelimited = 2;

  void _key(int field, int wireType) => _varint((field << 3) | wireType);

  void _varint(int value) {
    // Dart ints are 64-bit two's complement; a negative value must still be
    // encoded as an unsigned 64-bit varint (10 bytes), like protoc does.
    var v = value;
    if (v < 0) {
      for (var i = 0; i < 9; i++) {
        _out.addByte((v & 0x7f) | 0x80);
        v = v >>> 7;
      }
      _out.addByte(1);
      return;
    }
    while (v >= 0x80) {
      _out.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    _out.addByte(v);
  }

  /// int64 / uint64 / enum. Skipped when 0 (proto3 default).
  void int64(int field, int value) {
    if (value == 0) return;
    _key(field, _wireVarint);
    _varint(value);
  }

  /// Skipped when empty (proto3 default).
  void string(int field, String value) {
    if (value.isEmpty) return;
    final bytes = utf8.encode(value);
    _key(field, _wireLengthDelimited);
    _varint(bytes.length);
    _out.add(bytes);
  }

  /// Skipped when 0.0 (proto3 default).
  void float(int field, double value) {
    if (value == 0) return;
    _key(field, _wireFixed32);
    final b = ByteData(4)..setFloat32(0, value, Endian.little);
    _out.add(b.buffer.asUint8List());
  }

  /// Nested message. Empty messages are still written, because a repeated
  /// field entry exists even when all of its own fields are defaults.
  void message(int field, void Function(ProtoWriter w) build) {
    final nested = ProtoWriter();
    build(nested);
    final bytes = nested.toBytes();
    _key(field, _wireLengthDelimited);
    _varint(bytes.length);
    _out.add(bytes);
  }
}
