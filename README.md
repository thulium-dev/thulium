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
which persists the authenticated session and reusable credentials under separate
keys in platform secure storage. Passwords are never included in the shared
session model or calendar cache.

## CLI authentication

The Dart CLI provides interactive authentication and persists the resulting
session in the operating system credential store:

```bash
cd packages/cli
dart run bin/thulium.dart login
dart run bin/thulium.dart login --verbose
dart run bin/thulium.dart status
dart run bin/thulium.dart schedule
dart run bin/thulium.dart schedule --refresh
dart run bin/thulium.dart learn-courses
dart run bin/thulium.dart learn-courses --semester 2026-2027-1
dart run bin/thulium.dart learn-courses --refresh
dart run bin/thulium.dart logout
```

The optional `--verbose` flag prints safe authentication diagnostics for
troubleshooting. It never prints passwords, verification codes, or cookie
values. The CLI never accepts the password as a command-line argument and never writes
it to a project file. Linux uses Secret Service and macOS uses Keychain. Other
platforms will report that a secure session backend is not available until one
is added.

The application and CLI cache the current academic calendar per account in
platform secure storage. A successful fetch is reused for 24 hours; an older
copy can be shown if the portal is temporarily unavailable. Manual refresh and
`schedule --refresh` request a new copy instead of silently using stale data.
Logging out removes the saved calendar.

`learn-courses` fetches the learning platform's course list for the requested
semester and prints an English-keyed YAML view of the useful course fields.
Without `--semester`, it selects the semester from the local date: autumn
starts September 15, spring starts February 15, and summer starts July 15.
The app and CLI keep the selected account's current semester course list for
24 hours, with an older copy available if an update fails. Switching semesters
replaces this single snapshot. `--refresh` bypasses the
fresh cache. Study shows these courses, and the teaching calendar uses their
English titles for matching lessons when the app language is English. Custom
plans keep their original names. The output contains student-specific
information, so avoid redirecting it to a shared log.

When a protected CLI request reports an expired session, the CLI tries the
saved credentials, then offers an interactive sign-in if needed. A successful
reconnection retries the original request once.

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

Tests are grouped by scope: `test/unit/` covers logic and adapters, while
`test/widget/` covers Flutter components and screen behavior. Device-level
end-to-end tests belong in `integration_test/`.

```bash
flutter analyze
flutter test
dart analyze packages/cli
```
