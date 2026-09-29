import 'dart:io';
import 'package:integrity_studio_ai/services/content_loader.dart';

String _readRealContentYamlSync() {
  final file = File('content.yaml');
  if (!file.existsSync()) {
    throw StateError(
      'content.yaml not found. Run tests from the project root directory.',
    );
  }
  return file.readAsStringSync();
}

void loadRealContent() {
  ContentLoader.loadFromString(_readRealContentYamlSync());
}

Future<void> loadRealContentAsync() async {
  loadRealContent();
}

Future<String> readRealContentYaml() async => _readRealContentYamlSync();
