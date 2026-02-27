import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:integrity_studio_ai/theme/typography.dart';
import 'helpers/test_content.dart';

/// Global test configuration that runs before all tests.
///
/// This file is automatically detected by the Flutter test framework.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Disable Google Fonts network fetching in tests to avoid flaky tests
  // and network-related errors.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Use test font families to avoid GoogleFonts.inter() triggering
  // network/asset loading. Style properties (fontSize, fontWeight, etc.)
  // are tested directly; actual font rendering is not needed.
  AppTypography.setTestFonts();

  // Load content once at suite level for all tests.
  initializeTestContent();

  await testMain();
}
