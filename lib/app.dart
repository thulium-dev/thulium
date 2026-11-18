import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium_auth/thulium_auth.dart';

import 'auth/secure_auth_session_store.dart';
import 'auth/secure_course_schedule_cache_store.dart';
import 'auth/secure_learn_course_cache_store.dart';
import 'auth/secure_learn_homework_cache_store.dart';
import 'pages/home_page.dart';
import 'homework/homework_theme.dart';
import 'pages/welcome_page.dart';
import 'preferences/app_preferences_store.dart';

/// The root application widget owns global locale and theme state.
final class ThuliumApp extends StatefulWidget {
  const ThuliumApp({this.sessionStore, this.preferencesStore, super.key});

  /// Allows tests and alternate clients to provide their own session storage.
  final AuthSessionStore? sessionStore;
  final AppPreferencesStore? preferencesStore;

  @override
  State<ThuliumApp> createState() => _ThuliumAppState();
}

final class _ThuliumAppState extends State<ThuliumApp> {
  // The initial value follows the operating system. Once the user presses
  // the theme button, the app switches to an explicit light or dark mode.
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');
  bool _isRestoringState = true;
  bool _hasSession = false;
  late final AppPreferencesStore _preferencesStore =
      widget.preferencesStore ?? LocalAppPreferencesStore();
  Future<void> _preferenceWrites = Future<void>.value();

  @override
  void initState() {
    super.initState();
    unawaited(_restoreState());
  }

  Future<void> _restoreState() async {
    await Future.wait([_restoreSession(), _restorePreferences()]);
    if (mounted) setState(() => _isRestoringState = false);
  }

  Future<void> _restorePreferences() async {
    try {
      final preferences = await _preferencesStore.read();
      if (!mounted) return;
      _themeMode = preferences.themeMode;
      _locale = preferences.locale;
    } catch (error) {
      debugPrint('Thulium preference restoration failed: ${error.runtimeType}');
    }
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
    }
  }

  Future<bool> _logout() async {
    final sessionStore = widget.sessionStore ?? SecureAuthSessionStore();
    return AuthSessionRunner.exclusive(
      sessionStore,
      () => _logoutStoredSession(sessionStore),
    );
  }

  Future<bool> _logoutStoredSession(AuthSessionStore sessionStore) async {
    try {
      // Restore the persisted cookies before calling logout so the identity
      // service can invalidate the active remote session as well.
      final client = TsinghuaAuthClient(
        sessionStore: sessionStore,
        requestTimeout: const Duration(seconds: 8),
        credentialStore: sessionStore is AuthCredentialStore
            ? sessionStore as AuthCredentialStore
            : null,
      );
      await client.restore();
      await client.logout();
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

    if (widget.sessionStore == null) {
      try {
        await SecureCourseScheduleCacheStore().clear();
      } catch (error) {
        debugPrint('Thulium calendar cache removal failed: $error');
      }
      try {
        await SecureLearnCourseCacheStore().clear();
      } catch (error) {
        debugPrint('Thulium course cache removal failed: $error');
      }
      try {
        await SecureLearnHomeworkCacheStore().clear();
      } catch (error) {
        debugPrint('Thulium homework cache removal failed: $error');
      }
    }

    if (mounted) setState(() => _hasSession = false);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = withHomeworkTheme(FThemes.neutral.light.touch);
    final darkTheme = withHomeworkTheme(FThemes.neutral.dark.touch);

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
      home: _isRestoringState
          ? const FScaffold(child: Center(child: FCircularProgress()))
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
    _savePreferences();
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
    _savePreferences();
  }

  void _savePreferences() {
    final preferences = AppPreferences(themeMode: _themeMode, locale: _locale);
    // Serialize snapshots so a slower earlier write cannot replace the user's
    // latest language or theme choice. A failed write must not block later ones.
    _preferenceWrites = _preferenceWrites.then((_) async {
      try {
        await _preferencesStore.write(preferences);
      } catch (error) {
        debugPrint(
          'Thulium preference persistence failed: ${error.runtimeType}',
        );
      }
    });
  }
}
