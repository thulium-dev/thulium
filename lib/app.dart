import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium_auth/thulium_auth.dart';

import 'auth/secure_auth_session_store.dart';
import 'pages/home_page.dart';
import 'pages/welcome_page.dart';

/// The root application widget owns global locale and theme state.
final class ThuliumApp extends StatefulWidget {
  const ThuliumApp({this.sessionStore, super.key});

  /// Allows tests and alternate clients to provide their own session storage.
  final AuthSessionStore? sessionStore;

  @override
  State<ThuliumApp> createState() => _ThuliumAppState();
}

final class _ThuliumAppState extends State<ThuliumApp> {
  // The initial value follows the operating system. Once the user presses
  // the theme button, the app switches to an explicit light or dark mode.
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');
  bool _isRestoringSession = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final client = TsinghuaAuthClient(
        sessionStore: widget.sessionStore ?? SecureAuthSessionStore(),
      );
      // Restore the locally persisted session at launch without probing the
      // portal. Protected requests can validate it lazily after an auth error.
      _hasSession = await client.restore() != null;
    } catch (error) {
      // A secure-storage failure must not block access to the sign-in page.
      // Keep the failure visible in diagnostic logs without exposing secrets.
      debugPrint('Thulium session restoration failed: $error');
    } finally {
      if (mounted) setState(() => _isRestoringSession = false);
    }
  }

  Future<bool> _logout() async {
    final sessionStore = widget.sessionStore ?? SecureAuthSessionStore();
    try {
      // Restore the persisted cookies before calling logout so the identity
      // service can invalidate the active remote session as well.
      final client = TsinghuaAuthClient(
        sessionStore: sessionStore,
        credentialStore: sessionStore is AuthCredentialStore
            ? sessionStore as AuthCredentialStore
            : null,
      );
      await client.restore();
      await client.logout().timeout(const Duration(seconds: 8));
    } catch (error) {
      // Logout should still work offline: the auth client's finally block
      // clears local data, and this fallback covers failures during restore.
      debugPrint('Thulium remote logout failed: $error');
      try {
        try {
          await sessionStore.clear();
        } finally {
          if (sessionStore is AuthCredentialStore) {
            await (sessionStore as AuthCredentialStore).clearCredentials();
          }
        }
      } catch (storageError) {
        debugPrint('Thulium local session removal failed: $storageError');
        return false;
      }
    }

    if (mounted) setState(() => _hasSession = false);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = FThemes.neutral.light.touch;
    final darkTheme = FThemes.neutral.dark.touch;

    return MaterialApp(
      title: 'Thulium',
      theme: lightTheme.toApproximateMaterialTheme(),
      darkTheme: darkTheme.toApproximateMaterialTheme(),
      themeMode: _themeMode,
      // Keep Material's theme transition aligned with Forui's default
      // 200 ms linear FTheme transition so both widget systems change together.
      themeAnimationDuration: const Duration(milliseconds: 200),
      themeAnimationCurve: Curves.linear,
      locale: _locale,
      localizationsDelegates: [
        // AppLocalizations contains all user-facing Thulium strings. No
        // localized copy is hard-coded in the widget tree.
        ...AppLocalizations.localizationsDelegates,
        ...FLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        // Resolve both theme targets from the same mode value. Deriving this
        // from Theme.of(context) would read Material's in-progress transition
        // and could start the Forui transition partway through it.
        final dark = switch (_themeMode) {
          ThemeMode.light => false,
          ThemeMode.dark => true,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        final foruiTheme = dark ? darkTheme : lightTheme;
        // FTheme and MaterialApp now begin their matching 200 ms linear
        // transitions in the same frame.
        return FTheme(
          data: foruiTheme,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _isRestoringSession
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _hasSession
          ? HomePage(
              onLocaleSelected: _setLocale,
              onThemeToggle: _toggleTheme,
              onLogout: _logout,
              sessionStore: widget.sessionStore,
              onSessionExpired: () {
                if (mounted) setState(() => _hasSession = false);
              },
            )
          : WelcomePage(
              onLocaleSelected: _setLocale,
              onThemeToggle: _toggleTheme,
              onLoginSuccess: () => setState(() => _hasSession = true),
            ),
    );
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  void _toggleTheme() {
    setState(() {
      final isDark =
          _themeMode == ThemeMode.dark ||
          (_themeMode == ThemeMode.system &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark);
      _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    });
  }
}
