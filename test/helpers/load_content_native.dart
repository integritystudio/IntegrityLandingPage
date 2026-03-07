import 'dart:io';
import 'package:integrity_studio_ai/services/content_loader.dart';

void loadRealContent() {
  final file = File('content.yaml');
  if (!file.existsSync()) {
    throw StateError(
      'content.yaml not found. Run tests from the project root directory.',
    );
  }
  final yamlString = file.readAsStringSync();
  Content.loadFromString(yamlString);
}

Future<void> loadRealContentAsync() async {
  loadRealContent();
}
