import 'package:agent_ui_mobile/core/utils/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SseParser', () {
    test('parses a single event', () {
      final parser = SseParser();
      expect(parser.add('data: {"type":"status"}\n\n'), ['{"type":"status"}']);
    });

    test('parses several events in one chunk', () {
      final parser = SseParser();
      expect(parser.add('data: 1\n\ndata: 2\n\ndata: 3\n\n'), ['1', '2', '3']);
    });

    test('joins an event split across two chunks', () {
      final parser = SseParser();
      expect(parser.add('data: {"type":"fi'), isEmpty);
      expect(parser.add('nal"}\n\n'), ['{"type":"final"}']);
    });

    test('joins an event split across three chunks, including the blank line', () {
      final parser = SseParser();
      expect(parser.add('da'), isEmpty);
      expect(parser.add('ta: abc\n'), isEmpty);
      expect(parser.add('\ndata: next'), ['abc']);
      expect(parser.add('\n\n'), ['next']);
    });

    test('handles \\r\\n line endings, even when split between chunks', () {
      final parser = SseParser();
      expect(parser.add('data: a\r\n\r\ndata: b\r'), ['a']);
      expect(parser.add('\n\r\n'), ['b']);
    });

    test('handles lone \\r line endings', () {
      expect(SseParser().add('data: a\r\rdata: b\r\r\n'), ['a', 'b']);
    });

    test('ignores comments, event, id and retry lines', () {
      final parser = SseParser();
      expect(
        parser.add(': keep-alive\n\nevent: message\nid: 7\nretry: 100\ndata: x\n\n'),
        ['x'],
      );
    });

    test('accepts data: without a space and joins multi-line data', () {
      expect(SseParser().add('data:a\ndata: b\n\n'), ['a\nb']);
    });

    test('delivers a trailing event without its blank line when the stream ends', () {
      final parser = SseParser();
      expect(parser.add('data: 1\n\ndata: last'), ['1']);
      expect(parser.close(), ['last']);
      expect(parser.close(), isEmpty);
    });

    test('drops a trailing partial line that has no data', () {
      final parser = SseParser();
      parser.add('event: x\r');
      expect(parser.close(), isEmpty);
    });
  });

  test('sseData turns a chunked text stream into payloads', () async {
    final chunks = Stream.fromIterable(['data: {"a"', ':1}\n\ndata: 2\n', '\ndata: 3']);
    expect(await sseData(chunks).toList(), ['{"a":1}', '2', '3']);
  });
}
