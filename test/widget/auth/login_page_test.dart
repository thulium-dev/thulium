import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium/pages/login_page.dart';
import 'package:thulium/auth/secure_auth_session_store.dart';
import 'package:thulium_auth/thulium_auth.dart';

import '../../../packages/auth/test/support/fake_auth_http_client.dart';

class _Dialogs extends NavigatorObserver {
  int opened = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is FDialogRoute) opened++;
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  // Login deliberately keeps an indeterminate progress indicator alive while
  // a dialog waits for input, so bounded frame pumps replace pumpAndSettle.
  Future<void> tick(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> show(
    WidgetTester tester,
    FakeAuthHttpClient transport,
    _Dialogs dialogs, {
    VoidCallback? success,
    bool repeatTrustCallback = false,
  }) async {
    final theme = FThemes.neutral.dark.touch;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          ...AppLocalizations.localizationsDelegates,
          ...FLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme.toApproximateMaterialTheme(),
        navigatorObservers: [dialogs],
        builder: (_, child) => FTheme(data: theme, child: child!),
        home: LoginPage(
          onLoginSuccess: success ?? () {},
          authClientBuilder:
              ({
                required sessionStore,
                required credentialStore,
                required twoFactorMethodHandler,
                required twoFactorCodeHandler,
                required twoFactorTrustHandler,
                required twoFactorAuthLimitHandler,
                required trace,
              }) => TsinghuaAuthClient(
                httpClient: transport,
                sessionStore: sessionStore,
                credentialStore: credentialStore,
                twoFactorMethodHandler: twoFactorMethodHandler,
                twoFactorCodeHandler: twoFactorCodeHandler,
                twoFactorTrustHandler: () async {
                  final choice = await twoFactorTrustHandler();
                  if (repeatTrustCallback) {
                    expect(await twoFactorTrustHandler(), choice);
                  }
                  return choice;
                },
                twoFactorAuthLimitHandler: twoFactorAuthLimitHandler,
                trace: trace,
              ),
        ),
      ),
    );
    await tick(tester);
    await tester.enterText(find.byType(EditableText).first, '1234567890');
    await tester.enterText(find.byType(EditableText).last, 'password');
  }

  Future<void> verify(WidgetTester tester) async {
    await tester.tap(find.text('WeChat'));
    await tick(tester);
    await tester.enterText(find.byType(EditableText).last, '123456');
    // The fixture deliberately rejects the first submitted code.
    await tester.tap(find.text('Confirm'));
    await tick(tester);
    await tester.tap(find.text('Confirm'));
    await tick(tester);
    await tester.tap(find.text('Trust device'));
    await tick(tester);
  }

  testWidgets(
    'device quota explains the limit and allows an untrusted sign-in',
    (tester) async {
      final transport = FakeAuthHttpClient(trustRejectionMessage: '受信设备数已达上限');
      var successes = 0;
      await show(tester, transport, _Dialogs(), success: () => successes++);
      await tester.tap(find.text('Sign in'));
      await tick(tester);
      expect(find.text('Trust this device?'), findsNothing);
      await verify(tester);
      expect(find.text('Trusted device limit reached'), findsOneWidget);
      expect(find.textContaining('id.tsinghua.edu.cn'), findsOneWidget);
      expect(successes, 0);
      await tester.tap(find.text('Continue sign-in'));
      await tick(tester);
      // The portal may require its own code when registration was refused.
      await tester.tap(find.text('WeChat'));
      await tick(tester);
      await tester.enterText(find.byType(EditableText).last, '123456');
      await tester.tap(find.text('Confirm'));
      await tick(tester);
      expect(successes, 1);
      expect(find.text('Trust this device?'), findsNothing);
      expect((await SecureAuthSessionStore().read())!.trustedBrowser, isFalse);
      expect(
        transport.requests.where(
          (request) => request.url.path.endsWith('/saveFinger'),
        ),
        hasLength(1),
      );
    },
    semanticsEnabled: false,
  );

  testWidgets(
    'other registration rejection is visible and never reports successful sign-in',
    (tester) async {
      final transport = FakeAuthHttpClient(
        trustRejectionMessage: '身份异常 private-token',
      );
      var successes = 0;
      await show(tester, transport, _Dialogs(), success: () => successes++);
      await tester.tap(find.text('Sign in'));
      await tick(tester);
      await verify(tester);
      expect(
        find.textContaining('Could not trust this device'),
        findsOneWidget,
      );
      expect(find.textContaining('private-token'), findsNothing);
      expect(successes, 0);
      // The same screen can retry without registration, rather than trapping
      // an account behind a provider error from SAVE_FINGER.
      await tester.tap(find.text('Sign in'));
      await tick(tester);
      await tester.tap(find.text('WeChat'));
      await tick(tester);
      await tester.enterText(find.byType(EditableText).last, '123456');
      await tester.tap(find.text('Confirm'));
      await tick(tester);
      await tester.tap(find.text('Not now'));
      await tick(tester);
      await tester.tap(find.text('WeChat'));
      await tick(tester);
      await tester.enterText(find.byType(EditableText).last, '123456');
      await tester.tap(find.text('Confirm'));
      await tick(tester);
      expect(successes, 1);
      expect(
        transport.requests.where(
          (request) => request.url.path.endsWith('/saveFinger'),
        ),
        hasLength(1),
      );
    },
    semanticsEnabled: false,
  );

  testWidgets(
    'button plus keyboard submission does not restart trust after a verified login fails',
    (tester) async {
      final transport = FakeAuthHttpClient(failInformationRedirect: true);
      final dialogs = _Dialogs();
      await show(tester, transport, dialogs);
      final button = tester.widget<FButton>(
        find.widgetWithText(FButton, 'Sign in'),
      );
      final password = tester.widget<EditableText>(
        find.byType(EditableText).last,
      );
      // Both callbacks can be dispatched before the disabled button is rebuilt.
      button.onPress!();
      password.onSubmitted!('password');
      await tick(tester);
      await verify(tester);
      expect(find.text('Trust this device?'), findsNothing);
      expect(find.textContaining('Sign-in failed'), findsOneWidget);
      expect(dialogs.opened, 3); // trust, method, code
      expect(
        transport.requests.where((r) => r.url.path == '/login'),
        hasLength(1),
      );
    },
    // Flutter 3.47 + Forui form semantics currently assert in the framework.
    // This test exercises callback/routing behavior, not accessibility output.
    semanticsEnabled: false,
  );

  testWidgets('a successful two-stage login asks for trust only once', (
    tester,
  ) async {
    final transport = FakeAuthHttpClient(
      trustedPortalForm: true,
      trustWithoutToken: true,
    );
    final dialogs = _Dialogs();
    var successes = 0;
    await show(tester, transport, dialogs, success: () => successes++);
    await tester.tap(find.text('Sign in'));
    await tick(tester);
    await verify(tester);
    expect(successes, 1);
    expect(dialogs.opened, 3);
    expect(find.text('Trust this device?'), findsNothing);
    expect(
      transport.requests.where(
        (r) => r.url.path == '/do/off/ui/auth/login/checkSingle',
      ),
      hasLength(1),
    );
  }, semanticsEnabled: false);
  testWidgets('repeated trust callbacks reuse the choice within one attempt', (
    tester,
  ) async {
    final transport = FakeAuthHttpClient(
      trustedPortalForm: true,
      trustWithoutToken: true,
    );
    final dialogs = _Dialogs();
    var successes = 0;
    await show(
      tester,
      transport,
      dialogs,
      success: () => successes++,
      repeatTrustCallback: true,
    );
    await tester.tap(find.text('Sign in'));
    await tick(tester);
    await verify(tester);
    expect(successes, 1);
    expect(dialogs.opened, 3);
  }, semanticsEnabled: false);

  testWidgets('repeated trust and method taps cannot pop the following route', (
    tester,
  ) async {
    final transport = FakeAuthHttpClient(
      trustedPortalForm: true,
      trustWithoutToken: true,
    );
    final dialogs = _Dialogs();
    var successes = 0;
    await show(tester, transport, dialogs, success: () => successes++);
    await tester.tap(find.text('Sign in'));
    await tick(tester);
    final method = tester
        .widget<FButton>(find.widgetWithText(FButton, 'WeChat'))
        .onPress!;
    method();
    method();
    await tick(tester);
    expect(find.text('Verification code'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, '123456');
    await tester.tap(find.text('Confirm'));
    await tick(tester);
    await tester.tap(find.text('Confirm'));
    await tick(tester);
    final trust = tester
        .widget<FButton>(find.widgetWithText(FButton, 'Trust device'))
        .onPress!;
    trust();
    trust();
    await tick(tester);
    expect(successes, 1);
    expect(dialogs.opened, 3);
  }, semanticsEnabled: false);

  testWidgets(
    'repeated verification callbacks send only one in-flight request',
    (tester) async {
      final transport = FakeAuthHttpClient(
        trustedPortalForm: true,
        trustWithoutToken: true,
      );
      final dialogs = _Dialogs();
      var successes = 0;
      await show(tester, transport, dialogs, success: () => successes++);
      await tester.tap(find.text('Sign in'));
      await tick(tester);
      await tester.tap(find.text('WeChat'));
      await tick(tester);
      await tester.enterText(find.byType(EditableText).last, '123456');
      final confirm = tester
          .widget<FButton>(find.widgetWithText(FButton, 'Confirm'))
          .onPress!;
      confirm();
      confirm();
      await tick(tester);
      expect(
        find.text('That code was not accepted. Please try again'),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirm'));
      await tick(tester);
      await tester.tap(find.text('Trust device'));
      await tick(tester);
      expect(successes, 1);
      // Two requests total: one rejected code and one deliberate retry.
      expect(transport.verificationRequestCount, 2);
    },
    semanticsEnabled: false,
  );
}
