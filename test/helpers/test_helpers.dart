import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:integrity_studio_ai/theme/colors.dart';
import 'package:integrity_studio_ai/controllers/landing_controller.dart';
import 'package:integrity_studio_ai/services/content_loader.dart';
import 'test_content.dart';

// Re-export test content helpers for convenience
export 'test_content.dart'
    show initializeTestContent, resetTestContent, loadRealContent;

// Default theme for testing
final ThemeData testTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.gray900,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.blue500,
    secondary: AppColors.purple500,
    surface: AppColors.gray800,
  ),
);

// =============================================================================
// Content Initialization
// =============================================================================

/// Ensure test content is loaded before widget tests.
///
/// This is called automatically by testableWidget/testableSection.
void _ensureContentLoaded() {
  if (!Content.isLoaded) {
    initializeTestContent();
  }
}

// =============================================================================
// Widget Test Wrappers
// =============================================================================

/// Wraps a widget in MaterialApp for testing.
///
/// Automatically initializes test content if not already loaded.
Widget testableWidget(Widget child, {ThemeData? theme}) {
  _ensureContentLoaded();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme ?? testTheme,
    home: Scaffold(body: child),
  );
}

/// Wraps a section widget for testing.
///
/// Provides scroll context since sections are typically in ScrollView.
/// Automatically initializes test content if not already loaded.
Widget testableSection(Widget section, {ThemeData? theme}) {
  _ensureContentLoaded();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme ?? testTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: section,
      ),
    ),
  );
}

/// Wraps widget with providers for testing.
///
/// Automatically initializes test content if not already loaded.
Widget testableWidgetWithProviders(
  Widget child, {
  LandingController? landingController,
}) {
  _ensureContentLoaded();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: testTheme,
    home: MultiProvider(
      providers: [
        if (landingController != null)
          ChangeNotifierProvider<LandingController>.value(
            value: landingController,
          ),
      ],
      child: Scaffold(body: child),
    ),
  );
}

// =============================================================================
// WidgetTester Extensions
// =============================================================================

extension WidgetTesterX on WidgetTester {
  /// Pump widget wrapped in MaterialApp.
  Future<void> pumpApp(Widget widget) async {
    await pumpWidget(testableWidget(widget));
    await pumpAndSettle();
  }

  /// Pump section widget with scroll support.
  Future<void> pumpSection(Widget section) async {
    await pumpWidget(testableSection(section));
    await pumpAndSettle();
  }

  /// Pump widget with providers.
  Future<void> pumpAppWithProviders(
    Widget widget, {
    LandingController? landingController,
  }) async {
    await pumpWidget(
      testableWidgetWithProviders(
        widget,
        landingController: landingController,
      ),
    );
    await pumpAndSettle();
  }

  /// Scroll until widget is visible.
  Future<void> scrollUntilVisible(
    Finder finder, {
    double delta = 100,
    int maxScrolls = 50,
  }) async {
    int scrollCount = 0;
    while (!finder.evaluate().isNotEmpty && scrollCount < maxScrolls) {
      await drag(find.byType(SingleChildScrollView), Offset(0, -delta));
      await pumpAndSettle();
      scrollCount++;
    }
  }

  /// Wait for animations to complete with timeout.
  Future<void> pumpAndSettleWithTimeout({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  }

  /// Pump a fixed number of frames without waiting for animations to settle.
  ///
  /// Use this instead of pumpAndSettle() for pages with continuous animations
  /// that would cause pumpAndSettle to timeout. This approach is ~5x faster.
  /// Automatically clears overflow exceptions after pumping.
  Future<void> pumpFrames({int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await pump(const Duration(milliseconds: 100));
    }
    clearOverflowExceptions(this);
  }
}

// =============================================================================
// Finder Extensions
// =============================================================================

extension FinderX on CommonFinders {
  /// Find widget by semantic label.
  Finder bySemanticsLabel(String label) {
    return find.bySemanticsLabel(label);
  }

  /// Find text widget containing substring.
  Finder textContaining(String substring) {
    return find.textContaining(substring);
  }

  /// Find widget by type and text.
  Finder widgetWithText<T extends Widget>(String text) {
    return find.widgetWithText(T, text);
  }
}

// =============================================================================
// Test Utilities
// =============================================================================

/// Creates a test window size for responsive testing.
void setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Common screen sizes for responsive testing.
class TestScreenSizes {
  static const Size mobile = Size(375, 812); // iPhone X
  static const Size tablet = Size(768, 1024); // iPad
  static const Size desktop = Size(1440, 900); // Laptop
  static const Size desktopLarge = Size(1920, 1080); // Full HD
}

/// Set mobile viewport.
void setMobileSize(WidgetTester tester) {
  setScreenSize(tester, TestScreenSizes.mobile);
}

/// Set tablet viewport.
void setTabletSize(WidgetTester tester) {
  setScreenSize(tester, TestScreenSizes.tablet);
}

/// Set desktop viewport.
void setDesktopSize(WidgetTester tester) {
  setScreenSize(tester, TestScreenSizes.desktop);
}

// =============================================================================
// Assertion Helpers
// =============================================================================

/// Verify widget has expected text style.
void expectTextStyle(
  WidgetTester tester,
  Finder finder, {
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
}) {
  final widget = tester.widget<Text>(finder);
  final style = widget.style;

  if (color != null) {
    expect(style?.color, equals(color));
  }
  if (fontSize != null) {
    expect(style?.fontSize, equals(fontSize));
  }
  if (fontWeight != null) {
    expect(style?.fontWeight, equals(fontWeight));
  }
}

/// Verify container has expected decoration.
void expectContainerDecoration(
  WidgetTester tester,
  Finder finder, {
  Color? color,
  BorderRadius? borderRadius,
}) {
  final widget = tester.widget<Container>(finder);
  final decoration = widget.decoration as BoxDecoration?;

  if (color != null) {
    expect(decoration?.color, equals(color));
  }
  if (borderRadius != null) {
    expect(decoration?.borderRadius, equals(borderRadius));
  }
}

// =============================================================================
// Overflow Error Suppression
// =============================================================================

/// Check if an exception is an overflow error (visual-only, not functional).
bool isOverflowError(dynamic exception) {
  if (exception == null) return false;
  final message = exception.toString();
  return message.contains('overflowed') ||
      message.contains('RenderFlex') ||
      message.contains('A RenderFlex');
}

/// Check if FlutterErrorDetails represents an overflow error.
bool _isOverflowErrorDetails(FlutterErrorDetails details) {
  final exceptionMsg = details.exception.toString();
  final detailsMsg = details.toString();
  return exceptionMsg.contains('overflowed') ||
      exceptionMsg.contains('RenderFlex') ||
      exceptionMsg.contains('A RenderFlex') ||
      detailsMsg.contains('overflowed');
}

/// Clear overflow exceptions from the tester. Rethrows non-overflow exceptions.
void clearOverflowExceptions(WidgetTester tester) {
  dynamic exception = tester.takeException();
  while (exception != null) {
    if (!isOverflowError(exception)) {
      throw exception;
    }
    exception = tester.takeException();
  }
}

void Function(FlutterErrorDetails)? _originalOnError;

/// Set up overflow error suppression. Call in setUp().
void setUpOverflowErrorSuppression() {
  _originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (!_isOverflowErrorDetails(details)) {
      _originalOnError?.call(details);
    }
  };
}

/// Tear down overflow error suppression. Call in tearDown().
void tearDownOverflowErrorSuppression() {
  FlutterError.onError = _originalOnError;
}

// =============================================================================
// Test Data Generators
// =============================================================================

// =============================================================================
// Standard Page Test Helpers
// =============================================================================

/// Type for pump functions that create a page widget.
typedef PagePumpFunction = Future<void> Function(
  WidgetTester tester, {
  VoidCallback? onBack,
  bool mobile,
});

/// Test standard page structure elements (Scaffold, CustomScrollView, SliverAppBar, back button).
///
/// Call within a group() to add these standardized tests:
/// ```dart
/// group('page structure', () {
///   testPageStructure(pumpMyPage);
/// });
/// ```
void testPageStructure(
  Future<void> Function(WidgetTester) pumpPage, {
  bool hasBackButton = true,
}) {
  testWidgets('renders Scaffold', (tester) async {
    await pumpPage(tester);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('renders CustomScrollView', (tester) async {
    await pumpPage(tester);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('renders SliverAppBar', (tester) async {
    await pumpPage(tester);
    expect(find.byType(SliverAppBar), findsOneWidget);
  });

  if (hasBackButton) {
    testWidgets('renders back button', (tester) async {
      await pumpPage(tester);
      expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
    });
  }
}

/// Test back button callback functionality.
///
/// Call within a group() to add back button tests:
/// ```dart
/// group('navigation', () {
///   testBackButtonCallback(pumpMyPage);
/// });
/// ```
void testBackButtonCallback(PagePumpFunction pumpPage) {
  testWidgets('back button triggers onBack callback', (tester) async {
    bool backCalled = false;
    await pumpPage(tester, onBack: () => backCalled = true, mobile: false);

    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.pump();

    expect(backCalled, isTrue);
  });
}

/// Test back button and "Back to Home" text button callbacks.
///
/// Call within a group() to add both back button tests:
/// ```dart
/// group('navigation', () {
///   testBackButtonCallbacks(pumpMyPage);
/// });
/// ```
void testBackButtonCallbacks(PagePumpFunction pumpPage) {
  testBackButtonCallback(pumpPage);

  testWidgets('Back to Home button triggers onBack callback', (tester) async {
    bool backCalled = false;
    await pumpPage(tester, onBack: () => backCalled = true, mobile: false);

    await tester.tap(find.text('Back to Home'));
    await tester.pump();

    expect(backCalled, isTrue);
  });
}

/// Test responsive layout rendering across viewport sizes.
///
/// Call within a group() to add responsive tests:
/// ```dart
/// group('responsive layout', () {
///   testResponsiveLayout<MyPage>(pumpMyPage);
/// });
/// ```
void testResponsiveLayout<T extends Widget>(
  PagePumpFunction pumpPage, {
  String? expectedTitle,
  bool includeTablet = false,
}) {
  testWidgets('renders on mobile viewport', (tester) async {
    await pumpPage(tester, mobile: true);
    expect(find.byType(T), findsOneWidget);
    if (expectedTitle != null) {
      expect(find.text(expectedTitle), findsWidgets);
    }
  });

  testWidgets('renders on desktop viewport', (tester) async {
    await pumpPage(tester, mobile: false);
    expect(find.byType(T), findsOneWidget);
    if (expectedTitle != null) {
      expect(find.text(expectedTitle), findsWidgets);
    }
  });

  if (includeTablet) {
    testWidgets('renders on tablet viewport', (tester) async {
      setTabletSize(tester);
      clearOverflowExceptions(tester);
      // Need to call pump manually for tablet since pumpPage uses mobile bool
      await pumpPage(tester, mobile: false);
      expect(find.byType(T), findsOneWidget);
    });
  }
}

// =============================================================================
// Test Data Generators
// =============================================================================

/// Generate test consent preferences.
class TestData {
  static Map<String, dynamic> consentJson({
    bool essential = true,
    bool analytics = true,
    bool marketing = false,
  }) {
    return {
      'essential': essential,
      'analytics': analytics,
      'marketing': marketing,
      'timestamp': DateTime.now().toIso8601String(),
      'consentVersion': '1.0',
    };
  }

  static Map<String, dynamic> acceptAllConsentJson() {
    return consentJson(analytics: true, marketing: true);
  }

  static Map<String, dynamic> essentialOnlyConsentJson() {
    return consentJson(analytics: false, marketing: false);
  }
}
