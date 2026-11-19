import 'dart:convert';

import 'package:chat_ui_3/core/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<List<int>> chunks(List<String> parts) {
  return Stream.fromIterable(parts.map(utf8.encode));
}

void main() {
  test('parses a single data event', () async {
    final events = await SseParser()
        .parse(chunks(['data: hello\n\n']))
        .toList();
    expect(events, ['hello']);
  });

  test('handles CRLF, comments and blank lines', () async {
    final events = await SseParser()
        .parse(chunks([': keepalive\r\n', 'data: one\r\n\r\n', '\r\n']))
        .toList();
    expect(events, ['one']);
  });

  test('handles an event split across chunks', () async {
    final events = await SseParser()
        .parse(chunks(['data: {"a":', '1}\n\n']))
        .toList();
    expect(events, ['{"a":1}']);
  });

  test('joins multi-line data with newlines', () async {
    final events = await SseParser()
        .parse(chunks(['data: line1\ndata: line2\n\n']))
        .toList();
    expect(events, ['line1\nline2']);
  });

  test('flushes a trailing event without a blank line', () async {
    final events = await SseParser().parse(chunks(['data: tail\n'])).toList();
    expect(events, ['tail']);
  });

  test('accepts data with no space after the colon', () async {
    final events = await SseParser()
        .parse(chunks(['data:[DONE]\n\n']))
        .toList();
    expect(events, ['[DONE]']);
  });
}
