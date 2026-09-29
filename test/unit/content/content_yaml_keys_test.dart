// TS30: ContentLoader's string getters return '' for a key missing from content.yaml,
// so a dropped or misspelled key renders as blank text and nothing fails. The fixture
// table in content_loader_test proves each getter's path, never that the real file has it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/content_loader.dart';

import '../../helpers/content_string_getters.dart';

final _stringGetter = RegExp(r'static String get (\w+)');

void main() {
  setUpAll(() => ContentLoader.loadFromString(File('content.yaml').readAsStringSync()));

  test('the shared getter list names every string getter on ContentLoader', () {
    final source = File('lib/services/content_loader.dart').readAsStringSync();
    final declared = _stringGetter.allMatches(source).map((m) => m.group(1)).toSet();

    expect(contentStringGetters.keys.toSet(), declared);
  });

  for (final MapEntry(key: name, value: read) in contentStringGetters.entries) {
    test('$name is set in content.yaml', () {
      expect(read(), isNotEmpty);
    });
  }
}
