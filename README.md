# thulium

Thulium is a cross-platform Flutter application for Tsinghua University
students. It uses [Forui](https://github.com/duobaseio/forui) for UI components
and reserves `packages/cli` for future Dart command-line tools.

## Development

```bash
flutter pub get
flutter run -d chrome
```

The project currently uses Forui `0.22.x`, which is compatible with Flutter
3.44. Forui `0.26.x` requires Flutter 3.47 or newer; upgrade the dependency
after upgrading Flutter.

## Localization

Application strings are stored in ARB files under `lib/l10n` and generated with:

```bash
flutter gen-l10n
```

Add new user-facing strings to `app_en.arb` first, then add translations to the
other locale files. Do not put localized text directly in Dart source files.

## Authentication

Authentication logic is shared by the Flutter application and the future CLI
through `packages/auth`. The Flutter application uses `SecureAuthSessionStore`,
which persists only the authenticated session in platform secure storage.
Passwords are never persisted by the shared session model.

## CLI authentication

The Dart CLI provides interactive authentication and persists the resulting
session in the operating system credential store:

```bash
cd packages/cli
dart run bin/thulium.dart login
dart run bin/thulium.dart login --verbose
dart run bin/thulium.dart status
dart run bin/thulium.dart logout
```

The optional `--verbose` flag prints safe authentication diagnostics for
troubleshooting. It never prints passwords, verification codes, or cookie
values. The CLI never accepts the password as a command-line argument and never writes
it to a project file. Linux uses Secret Service and macOS uses Keychain. Other
platforms will report that a secure session backend is not available until one
is added.

Interactive login attempts can be retried after credential, verification-code,
or network errors. Each retry starts a fresh authentication flow.

## Project structure

```text
lib/                    Flutter application
lib/l10n/               ARB resources and generated localization code
packages/auth/          Shared Dart authentication and session library
packages/cli/           Standalone Dart CLI package for future tools
android/ ios/ web/      Mobile and web targets
linux/ macos/ windows/  Desktop targets
```

## Checks

```bash
flutter analyze
flutter test
dart analyze packages/cli
```
