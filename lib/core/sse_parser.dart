import 'dart:convert';

class SseParser {
  Stream<String> parse(Stream<List<int>> source) async* {
    final data = StringBuffer();
    await for (final line
        in source.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          final event = data.toString();
          data.clear();
          yield event;
        }
        continue;
      }
      if (line.startsWith(':')) {
        continue;
      }
      if (!line.startsWith('data:')) {
        continue;
      }
      var value = line.substring(5);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
      if (data.isNotEmpty) {
        data.write('\n');
      }
      data.write(value);
    }
    if (data.isNotEmpty) {
      yield data.toString();
    }
  }
}
