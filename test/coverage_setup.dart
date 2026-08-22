/// Coverage setup - imports all lib modules to ensure coverage instrumentation.
/// This file forces all source files to be loaded during test execution,
/// which ensures they appear in the coverage data even if not directly tested.
library;

// ignore: unused_import
import 'package:integrity_studio_ai/app.dart';

// Remaining imports for files not transitively imported by app.dart
// ignore: unused_import
import 'package:integrity_studio_ai/main.dart';

// Services - platform-specific stubs/web
// ignore: unused_import
import 'package:integrity_studio_ai/services/auth_storage_stub.dart';
// ignore: unused_import
import 'package:integrity_studio_ai/services/tracking.dart';
// ignore: unused_import
import 'package:integrity_studio_ai/services/url_launcher.dart';

/// Force all modules to be loaded to ensure coverage instrumentation.
void ensureCoverageInstrumentation() {
  // This function body is empty - its purpose is just to ensure all imports
  // above are executed, which causes the Dart VM to instrument all the imported
  // files for coverage collection.
}
