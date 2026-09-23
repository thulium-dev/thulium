import 'package:flutter_test/flutter_test.dart';
import 'package:thulium_auth/thulium_auth.dart';

import 'package:thulium/app.dart';

void main() {
  testWidgets('shows the Thulium welcome page', (tester) async {
    await tester.pumpWidget(ThuliumApp(sessionStore: MemoryAuthSessionStore()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, THUer'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('restores the authenticated home from a saved session', (
    tester,
  ) async {
    final store = MemoryAuthSessionStore();
    await store.write(
      const AuthSession(userId: '2022012050', fingerprint: 'test', cookies: {}),
    );

    await tester.pumpWidget(ThuliumApp(sessionStore: store));
    await tester.pumpAndSettle();

    expect(find.text('Student events'), findsOneWidget);
    expect(find.text('Welcome, THUer'), findsNothing);
  });

  testWidgets('opens settings from the authenticated home', (tester) async {
    final store = MemoryAuthSessionStore();
    await store.write(
      const AuthSession(userId: '2022012050', fingerprint: 'test', cookies: {}),
    );

    await tester.pumpWidget(ThuliumApp(sessionStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });
}
