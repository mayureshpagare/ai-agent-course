import 'dart:async';

/// Incremental parser for a `text/event-stream` body.
///
/// Feed it decoded text as it arrives, in chunks of any size. It returns the
/// `data` of every event that is complete so far. One event can be split
/// across chunks, and one chunk can hold several events. Only `data:` matters
/// to this backend, so `event:`, `id:`, `retry:` and `:` comment lines are
/// skipped. Lines may end in `\n`, `\r\n` or `\r`.
class SseParser {
  String _pending = '';

  /// Adds [chunk] and returns the data of each event it completed.
  List<String> add(String chunk) {
    _pending = _normalizeLineEnds(_pending + chunk);
    final events = <String>[];
    int boundary;
    while ((boundary = _pending.indexOf('\n\n')) != -1) {
      final data = _dataOf(_pending.substring(0, boundary));
      _pending = _pending.substring(boundary + 2);
      if (data != null) events.add(data);
    }
    return events;
  }

  /// Ends the stream. A last event that is missing its blank line is still
  /// delivered: the backend always ends events properly, so leftover text is a
  /// complete event from a server that closed early rather than a fragment.
  List<String> close() {
    var rest = _pending;
    _pending = '';
    if (rest.endsWith('\r')) rest = rest.substring(0, rest.length - 1);
    final data = _dataOf(rest);
    return data == null ? const [] : [data];
  }

  /// Turns `\r\n` and lone `\r` into `\n`. A trailing `\r` may be the first
  /// half of a `\r\n` that was split across chunks, so it waits for more text.
  static String _normalizeLineEnds(String text) {
    var result = text.replaceAll('\r\n', '\n');
    final trailingCr = result.endsWith('\r');
    if (trailingCr) result = result.substring(0, result.length - 1);
    result = result.replaceAll('\r', '\n');
    return trailingCr ? '$result\r' : result;
  }

  static String? _dataOf(String block) {
    final lines = <String>[];
    for (final line in block.split('\n')) {
      if (!line.startsWith('data:')) continue;
      final value = line.substring(5);
      lines.add(value.startsWith(' ') ? value.substring(1) : value);
    }
    return lines.isEmpty ? null : lines.join('\n');
  }
}

/// Splits a stream of decoded text into SSE event data payloads.
///
/// Built from handlers rather than an `async*` generator so that cancelling
/// the result cancels [text] at once, even while waiting for the next chunk.
Stream<String> sseData(Stream<String> text) {
  final parser = SseParser();
  return text.transform(StreamTransformer.fromHandlers(
    handleData: (chunk, sink) => parser.add(chunk).forEach(sink.add),
    handleDone: (sink) {
      parser.close().forEach(sink.add);
      sink.close();
    },
  ));
}
