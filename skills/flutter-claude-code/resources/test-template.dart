// Standard widget test template for IntegrityLandingPage
// INSTRUCTIONS: Copy this file and replace the following placeholders:
// - YourWidgetName: The actual widget class name to test
// - 'Expected Text': The text your widget renders
// - Uncomment and update the import paths below

// import 'package:flutter_test/flutter_test.dart';
// import 'package:flutter/material.dart';
// import 'package:integrity_studio_ai/widgets/YOUR_WIDGET_PATH.dart';
// import '../../helpers/test_helpers.dart';
//
// void main() {
//   group('YourWidgetName', () {
//     late Widget widget;
//
//     setUpAll(() {
//       widget = MaterialApp(home: Scaffold(body: const YourWidgetName()));
//     });
//
//     setUp(() {
//       setUpOverflowErrorSuppression();
//     });
//
//     tearDown(() {
//       tearDownOverflowErrorSuppression();
//     });
//
//     group('desktop', () {
//       Future<void> pumpDesktop(WidgetTester tester) async {
//         setDesktopSize(tester);
//         await tester.pumpWidget(widget);
//         await tester.pump();
//       }
//
//       testWidgets('renders heading', (tester) async {
//         await pumpDesktop(tester);
//         expect(find.text('Expected Text'), findsOneWidget);
//       });
//     });
//
//     group('mobile', () {
//       Future<void> pumpMobile(WidgetTester tester) async {
//         setMobileSize(tester);
//         await tester.pumpWidget(widget);
//         await tester.pump();
//       }
//
//       testWidgets('renders on mobile', (tester) async {
//         await pumpMobile(tester);
//         expect(find.byType(YourWidgetName), findsOneWidget);
//       });
//     });
//   });
// }
