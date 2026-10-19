/// Small helpers for reading untrusted JSON without casts that can throw.
library;

typedef Json = Map<String, dynamic>;

/// [value] as a JSON object, or null when it is not one.
Json? asJson(Object? value) =>
    value is Map ? value.map((key, item) => MapEntry('$key', item)) : null;

/// A required string field. Throws [FormatException] when it is missing.
String requireString(Json json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a string, got ${value.runtimeType}.');
}

/// An optional string field. Non-string scalars are converted, null stays null.
String? optionalString(Json json, String key) {
  final value = json[key];
  if (value == null) return null;
  return value is String ? value : '$value';
}

double asDouble(Object? value) => value is num ? value.toDouble() : 0;

bool asBool(Object? value) => value == true;
