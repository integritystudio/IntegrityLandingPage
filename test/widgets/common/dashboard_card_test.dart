import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/widgets/common/dashboard_card.dart';
import '../../helpers/test_helpers.dart';

void main() {
  const title = 'Card Title';
  const bodyText = 'Body content';
  const trailingKey = Key('trailing');

  Widget buildCard({bool isLoading = false, Widget? trailing}) {
    return testableWidget(
      DashboardCard(
        title: title,
        isLoading: isLoading,
        trailing: trailing,
        children: const [Text(bodyText)],
      ),
    );
  }

  group('DashboardCard', () {
    testWidgets('renders title and children', (tester) async {
      await tester.pumpWidget(buildCard());

      expect(find.text(title), findsOneWidget);
      expect(find.text(bodyText), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows a spinner while loading', (tester) async {
      await tester.pumpWidget(buildCard(isLoading: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('trailing widget replaces the spinner even while loading',
        (tester) async {
      await tester.pumpWidget(buildCard(
        isLoading: true,
        trailing: const SizedBox(key: trailingKey),
      ));

      expect(find.byKey(trailingKey), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
