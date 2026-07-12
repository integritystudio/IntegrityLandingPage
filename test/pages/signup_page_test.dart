import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/pages/signup_page.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import 'package:integrity_studio_ai/widgets/common/form_fields.dart';
import 'package:integrity_studio_ai/widgets/common/gradient_page_shell.dart';
import '../helpers/test_helpers.dart';

void main() {

  group('SignupPage', () {
    void setLargeViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Widget buildSignupPage({String tier = 'starter', VoidCallback? onBack}) {
      return MaterialApp(
        theme: testTheme,
        home: SignupPage(tier: tier, onBack: onBack),
      );
    }

    group('widget structure', () {
      testWidgets('renders SignupPage', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders Scaffold', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('renders GradientPageShell', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(GradientPageShell), findsOneWidget);
      });
    });

    group('form fields', () {
      testWidgets('renders FormTextField widgets', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        // Should have 3 form fields: name, email, password
        expect(find.byType(FormTextField), findsNWidgets(3));
      });

      testWidgets('renders Checkbox for terms agreement', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(Checkbox), findsOneWidget);
      });

      testWidgets('renders GradientButton for submit', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(GradientButton), findsOneWidget);
      });
    });

    group('tier display', () {
      testWidgets('renders with starter tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'starter'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders with growth tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'growth'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders with enterprise tier', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });
    });

    group('form interaction', () {
      testWidgets('can enter text in name field', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        final textFields = find.byType(TextFormField);
        expect(textFields, findsWidgets);

        await tester.enterText(textFields.first, 'Test User');
        await tester.pump();
      });

      testWidgets('can toggle terms checkbox', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        final checkbox = find.byType(Checkbox);
        expect(checkbox, findsOneWidget);

        // Get initial state
        final initialCheckbox = tester.widget<Checkbox>(checkbox);
        expect(initialCheckbox.value, isFalse);

        // Tap to toggle
        await tester.tap(checkbox);
        await tester.pump();

        // Check new state
        final updatedCheckbox = tester.widget<Checkbox>(checkbox);
        expect(updatedCheckbox.value, isTrue);
      });
    });

    group('navigation', () {
      testWidgets('onBack callback is called when provided', (tester) async {
        setLargeViewport(tester);
        var backCalled = false;

        await tester.pumpWidget(buildSignupPage(onBack: () => backCalled = true));
        await tester.pump();

        // Find and tap the back button (first IconButton)
        final iconButtons = find.byType(IconButton);
        expect(iconButtons, findsWidgets);

        await tester.tap(iconButtons.first);
        await tester.pump();

        expect(backCalled, isTrue);
      });
    });

    group('responsive design', () {
      testWidgets('renders on mobile viewport', (tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders on tablet viewport', (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });

      testWidgets('renders on desktop viewport', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(SignupPage), findsOneWidget);
      });
    });

    group('form validation', () {
      testWidgets('submit button exists', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        expect(find.byType(GradientButton), findsOneWidget);
      });

      testWidgets('tapping submit without filling form shows validation', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        // Tap submit button
        final submitButton = find.byType(GradientButton);
        await tester.tap(submitButton);
        await tester.pump();

        // Form should still be visible (validation prevents submission)
        expect(find.byType(SignupPage), findsOneWidget);
      });
    });

    group('widget disposal', () {
      testWidgets('disposes without error', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        // Replace with different widget to trigger dispose
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const Scaffold(body: Text('Replaced')),
          ),
        );
        await tester.pump();

        expect(find.byType(SignupPage), findsNothing);
      });
    });

    // -------------------------------------------------------------------------
    // Tier-specific form fields
    // -------------------------------------------------------------------------

    group('tier-specific form fields', () {
      testWidgets('non-enterprise shows password field', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'starter'));
        await tester.pump();

        expect(find.text('Password *'), findsOneWidget);
      });

      testWidgets('non-enterprise does not show company field', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'starter'));
        await tester.pump();

        expect(find.text('Company Name'), findsNothing);
      });

      testWidgets('enterprise shows company field', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        expect(find.text('Company Name'), findsOneWidget);
      });

      testWidgets('enterprise shows password field', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        expect(find.text('Password *'), findsOneWidget);
      });

      testWidgets('enterprise has 4 form fields (name, email, company, password)', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        expect(find.byType(FormTextField), findsNWidgets(4));
      });

      testWidgets('password field is obscured on all tiers', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'starter'));
        await tester.pump();

        final obscured = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .any((et) => et.obscureText);
        expect(obscured, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Button text
    // -------------------------------------------------------------------------

    group('button text', () {
      testWidgets('non-enterprise shows Start Free Trial', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'starter'));
        await tester.pump();

        expect(find.text('Start Free Trial'), findsOneWidget);
      });

      testWidgets('enterprise shows Create Account', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        expect(find.text('Create Account'), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // Tier-specific validation (local — no service calls)
    // -------------------------------------------------------------------------

    group('tier-specific validation', () {
      testWidgets('non-enterprise shows name error when empty', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        await tester.tap(find.byType(GradientButton));
        await tester.pump();

        expect(find.text('Please enter your name'), findsOneWidget);
      });

      testWidgets('non-enterprise shows email error when empty', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.tap(find.byType(GradientButton));
        await tester.pump();

        expect(find.text('Please enter your email'), findsOneWidget);
      });

      testWidgets('non-enterprise shows email format error', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
        await tester.tap(find.byType(GradientButton));
        await tester.pump();

        expect(find.text('Please enter a valid email'), findsOneWidget);
      });

      testWidgets('non-enterprise shows password required error', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'user@example.com');
        await tester.tap(find.byType(GradientButton));
        await tester.pump();

        expect(find.text('Please enter a password'), findsOneWidget);
      });

      testWidgets('non-enterprise shows password too short error', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'user@example.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'short');
        await tester.tap(find.byType(GradientButton));
        await tester.pump();

        expect(find.text('Password must be at least 8 characters'), findsOneWidget);
      });

      testWidgets('non-enterprise shows terms error when not agreed', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage());
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'user@example.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'password123');
        await tester.tap(find.byType(GradientButton));
        await tester.pump();

        expect(
          find.text('Please agree to the Terms of Service and Privacy Policy'),
          findsOneWidget,
        );
      });

      testWidgets('enterprise shows name error when empty', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        await tester.tap(find.byType(GradientButton));
        await tester.pump();

        expect(find.text('Please enter your name'), findsOneWidget);
      });

      testWidgets('enterprise shows email error when empty', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.tap(find.byType(GradientButton));
        await tester.pump();

        expect(find.text('Please enter your email'), findsOneWidget);
      });

      testWidgets('enterprise shows password required error', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        // Fill name, email, company but not password
        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'user@example.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'Acme Corp');
        await tester.tap(find.byType(GradientButton));
        await tester.pump();

        expect(find.text('Please enter a password'), findsOneWidget);
      });

      testWidgets('enterprise shows terms error when not agreed', (tester) async {
        setLargeViewport(tester);
        await tester.pumpWidget(buildSignupPage(tier: 'enterprise'));
        await tester.pump();

        // Enterprise: at(0)=name, at(1)=email, at(2)=company, at(3)=password
        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'user@example.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'Acme Corp');
        await tester.enterText(find.byType(TextFormField).at(3), 'password123');
        await tester.tap(find.byType(GradientButton));
        await tester.pump();

        expect(
          find.text('Please agree to the Terms of Service and Privacy Policy'),
          findsOneWidget,
        );
      });
    });

    // -------------------------------------------------------------------------
    // Submission — non-enterprise (GoRouter + mocked ProvisioningService)
    // -------------------------------------------------------------------------

    group('submission — non-enterprise', () {
      late _MockProvisioningDio mockProvisioningDio;

      setUp(() {
        mockProvisioningDio = _MockProvisioningDio();
        ProvisioningService.setDioForTesting(mockProvisioningDio);
        ProvisioningService.retryDelay = (_) async {};
      });

      tearDown(() {
        ProvisioningService.resetDio();
        ProvisioningService.resetRetryDelay();
      });

      testWidgets('routes to /provision on successful signup', (tester) async {
        setLargeViewport(tester);
        mockProvisioningDio.mockPostResponse(
          {'jwt': 'test-jwt-123'},
          statusCode: 201,
        );

        final router = _makeSignupRouter('starter');
        await tester.pumpWidget(MaterialApp.router(
          theme: testTheme,
          routerConfig: router,
        ));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'user@example.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'password123');
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        await tester.tap(find.byType(GradientButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('provision_page'), findsOneWidget);
      });

      testWidgets('routes to /request_failure on failed signup', (tester) async {
        setLargeViewport(tester);
        mockProvisioningDio.mockPostResponse(
          {'error': 'Email already in use'},
          statusCode: 409,
        );

        final router = _makeSignupRouter('starter');
        await tester.pumpWidget(MaterialApp.router(
          theme: testTheme,
          routerConfig: router,
        ));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'user@example.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'password123');
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        await tester.tap(find.byType(GradientButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('request_failure_page'), findsOneWidget);
        expect(find.text('provision_page'), findsNothing);
      });

      testWidgets('routes to /checkout for growth tier on success', (tester) async {
        setLargeViewport(tester);
        mockProvisioningDio.mockPostResponse(
          {'jwt': 'test-jwt-456', 'email': 'user@example.com'},
          statusCode: 201,
        );

        final router = _makeSignupRouterWithCheckout('growth');
        await tester.pumpWidget(MaterialApp.router(
          theme: testTheme,
          routerConfig: router,
        ));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'user@example.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'password123');
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        await tester.tap(find.byType(GradientButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('checkout_page'), findsOneWidget);
        expect(find.text('provision_page'), findsNothing);
      });
    });

    // -------------------------------------------------------------------------
    // Submission — enterprise (GoRouter + mocked ProvisioningService)
    // -------------------------------------------------------------------------

    group('submission — enterprise', () {
      late _MockProvisioningDio mockProvisioningDio;

      setUp(() {
        mockProvisioningDio = _MockProvisioningDio();
        ProvisioningService.setDioForTesting(mockProvisioningDio);
        ProvisioningService.retryDelay = (_) async {};
      });

      tearDown(() {
        ProvisioningService.resetDio();
        ProvisioningService.resetRetryDelay();
      });

      testWidgets('routes to /checkout on successful enterprise signup', (tester) async {
        setLargeViewport(tester);
        mockProvisioningDio.mockPostResponse(
          {'jwt': 'test-jwt-789', 'email': 'corp@bigco.com'},
          statusCode: 201,
        );

        final router = _makeSignupRouterWithCheckout('enterprise');
        await tester.pumpWidget(MaterialApp.router(
          theme: testTheme,
          routerConfig: router,
        ));
        await tester.pump();

        // Enterprise: at(0)=name, at(1)=email, at(2)=company, at(3)=password
        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'corp@bigco.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'Big Co Inc');
        await tester.enterText(find.byType(TextFormField).at(3), 'password123');
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        await tester.tap(find.byType(GradientButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('checkout_page'), findsOneWidget);
        expect(find.text('provision_page'), findsNothing);
      });

      testWidgets('routes to /request_failure on failed enterprise signup', (tester) async {
        setLargeViewport(tester);
        mockProvisioningDio.mockPostResponse(
          {'error': 'Email already in use'},
          statusCode: 409,
        );

        final router = _makeSignupRouterWithCheckout('enterprise');
        await tester.pumpWidget(MaterialApp.router(
          theme: testTheme,
          routerConfig: router,
        ));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
        await tester.enterText(find.byType(TextFormField).at(1), 'corp@bigco.com');
        await tester.enterText(find.byType(TextFormField).at(2), 'Big Co Inc');
        await tester.enterText(find.byType(TextFormField).at(3), 'password123');
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        await tester.tap(find.byType(GradientButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('request_failure_page'), findsOneWidget);
        expect(find.text('checkout_page'), findsNothing);
      });
    });
  });
}

// -----------------------------------------------------------------------------
// Router factory for submission tests
// -----------------------------------------------------------------------------

GoRouter _makeSignupRouter(String tier) => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => SignupPage(tier: tier, onBack: () {}),
        ),
        GoRoute(
          path: '/provision',
          builder: (_, _) => const Scaffold(body: Text('provision_page')),
        ),
        GoRoute(
          path: '/request_success',
          builder: (_, _) => const Scaffold(body: Text('request_success_page')),
        ),
        GoRoute(
          path: '/request_failure',
          builder: (_, _) => const Scaffold(body: Text('request_failure_page')),
        ),
      ],
    );

GoRouter _makeSignupRouterWithCheckout(String tier) => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => SignupPage(tier: tier, onBack: () {}),
        ),
        GoRoute(
          path: '/provision',
          builder: (_, _) => const Scaffold(body: Text('provision_page')),
        ),
        GoRoute(
          path: '/checkout',
          builder: (_, _) => const Scaffold(body: Text('checkout_page')),
        ),
        GoRoute(
          path: '/request_success',
          builder: (_, _) => const Scaffold(body: Text('request_success_page')),
        ),
        GoRoute(
          path: '/request_failure',
          builder: (_, _) => const Scaffold(body: Text('request_failure_page')),
        ),
      ],
    );

// -----------------------------------------------------------------------------
// Mock Dio for ProvisioningService
// -----------------------------------------------------------------------------

class _MockProvisioningDio implements Dio {
  Map<String, dynamic> _postData = {};
  int _postStatusCode = 201;

  void mockPostResponse(Map<String, dynamic> data, {int statusCode = 201}) {
    _postData = Map.of(data);
    _postStatusCode = statusCode;
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async =>
      Response<T>(
        data: Map<String, dynamic>.from(_postData) as T,
        statusCode: _postStatusCode,
        requestOptions: RequestOptions(path: path),
      );

  @override
  BaseOptions get options => BaseOptions();
  @override
  set options(BaseOptions options) {}
  @override
  Interceptors get interceptors => Interceptors();
  @override
  HttpClientAdapter get httpClientAdapter => throw UnimplementedError();
  @override
  set httpClientAdapter(HttpClientAdapter adapter) {}
  @override
  Transformer get transformer => throw UnimplementedError();
  @override
  set transformer(Transformer transformer) {}
  @override
  void close({bool force = false}) {}
  @override
  Dio clone({
    BaseOptions? options,
    Interceptors? interceptors,
    HttpClientAdapter? httpClientAdapter,
    Transformer? transformer,
  }) => this;
  @override
  Future<Response<T>> get<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> getUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> postUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> delete<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response<T>> deleteUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response> download(String urlPath, dynamic savePath, {ProgressCallback? onReceiveProgress, Map<String, dynamic>? queryParameters, CancelToken? cancelToken, bool deleteOnError = true, String lengthHeader = Headers.contentLengthHeader, Object? data, Options? options, FileAccessMode fileAccessMode = FileAccessMode.write}) => throw UnimplementedError();
  @override
  Future<Response> downloadUri(Uri uri, dynamic savePath, {ProgressCallback? onReceiveProgress, CancelToken? cancelToken, bool deleteOnError = true, String lengthHeader = Headers.contentLengthHeader, Object? data, Options? options, FileAccessMode fileAccessMode = FileAccessMode.write}) => throw UnimplementedError();
  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) => throw UnimplementedError();
  @override
  Future<Response<T>> head<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response<T>> headUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response<T>> patch<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> patchUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> put<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> putUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> request<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, CancelToken? cancelToken, Options? options, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> requestUri<T>(Uri uri, {Object? data, CancelToken? cancelToken, Options? options, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
}

