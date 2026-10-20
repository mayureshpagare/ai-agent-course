import 'dart:convert';

import '../data/models/chat_item.dart';

/// Header text of a finished activity group, e.g. "Thought, used 2 tools".
/// Same wording as `summary()` in the web app's ActivityGroup.tsx.
String activitySummary(List<ActivityStep> steps) {
  final tools = steps.whereType<ToolItem>().length;
  final thought = steps.any((step) => step is ThinkingItem);
  final parts = [
    if (thought) 'Thought',
    if (tools > 0) 'used $tools tool${tools == 1 ? '' : 's'}',
  ];
  final text = parts.join(', ');
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// One-line arguments, e.g. `path="notes.txt", limit=5`, as the web app shows them.
String argSummary(Map<String, dynamic> args) =>
    args.entries.map((entry) {
      final value = entry.value;
      return '${entry.key}=${value is String ? '"$value"' : _jsonLike(value)}';
    }).join(', ');

/// A tool result as pretty-printed JSON when it parses, else the raw text.
String prettyResult(Object? value) {
  if (value is String) {
    try {
      return _indented.convert(_normalizeNumbers(jsonDecode(value)));
    } on FormatException {
      return value;
    }
  }
  return _indented.convert(_normalizeNumbers(value));
}

const _indented = JsonEncoder.withIndent('  ');

String _jsonLike(Object? value) => jsonEncode(_normalizeNumbers(value));

/// JavaScript prints `3.0` as `3`; match it so both apps show the same text.
Object? _normalizeNumbers(Object? value) => switch (value) {
      final double number when number.isFinite && number == number.truncateToDouble() => number.toInt(),
      final Map<dynamic, dynamic> map => map.map((key, item) => MapEntry('$key', _normalizeNumbers(item))),
      final List<dynamic> list => list.map(_normalizeNumbers).toList(),
      _ => value,
    };
