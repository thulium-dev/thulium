import 'package:flutter_test/flutter_test.dart';

import 'package:thulium/main.dart';

void main() {
  testWidgets('shows the Thulium welcome page', (tester) async {
    await tester.pumpWidget(const ThuliumApp());

    expect(find.text('Thulium'), findsOneWidget);
    expect(find.text('Welcome, Tsinghua student'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
  });
}
