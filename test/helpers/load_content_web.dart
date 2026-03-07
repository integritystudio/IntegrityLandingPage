import 'package:flutter/services.dart';
import 'package:integrity_studio_ai/services/content_loader.dart';

void loadRealContent() {
  // On web, dart:io is unavailable. Load content.yaml from Flutter assets.
  // This is synchronous-shaped but uses a deferred async load pattern:
  // flutter_test_config.dart calls initializeTestContent() which is async-capable.
  throw UnsupportedError(
    'loadRealContent() is synchronous and cannot use rootBundle on web. '
    'Use loadRealContentAsync() instead.',
  );
}

Future<void> loadRealContentAsync() async {
  final yamlString = await rootBundle.loadString('content.yaml');
  Content.loadFromString(yamlString);
}
