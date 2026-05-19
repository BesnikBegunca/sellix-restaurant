/// Redacts sensitive keys from support bundle payloads.
library;

/// Returns `true` when [key] should never appear in support exports.
bool isSensitiveBundleKey(String key) {
  final k = key.toLowerCase();
  return k.contains('token') ||
      k.contains('password') ||
      k.contains('pin') ||
      k.contains('hash') ||
      k.contains('secret') ||
      k.contains('activationkey') ||
      k.contains('activation_key');
}

/// Redacts a single map entry when the key is sensitive.
dynamic redactSensitiveValue(String key, dynamic value) {
  if (isSensitiveBundleKey(key)) {
    return '<redacted>';
  }
  return redactValue(value);
}

/// Deep-redacts maps/lists for JSON export.
dynamic redactValue(dynamic value) {
  if (value is Map) {
    return redactMap(Map<String, dynamic>.from(value));
  }
  if (value is List) {
    return value.map(redactValue).toList();
  }
  return value;
}

Map<String, dynamic> redactMap(Map<String, dynamic> map) {
  final out = <String, dynamic>{};
  for (final entry in map.entries) {
    out[entry.key] = redactSensitiveValue(entry.key, entry.value);
  }
  return out;
}
