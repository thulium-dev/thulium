# thulium

Thulium is a cross-platform Flutter application for Tsinghua University students. It uses [Forui](https://github.com/duobaseio/forui) for UI components and reserves `packages/cli` for future Dart command-line tools.

## Development

```bash
flutter pub get
flutter run -d chrome
```

The project currently uses Forui `0.22.x`, which is compatible with Flutter 3.44. Forui `0.26.x` requires Flutter 3.47 or newer; upgrade the dependency after upgrading Flutter.

## Localization

Application strings are stored in ARB files under `lib/l10n` and generated with:

```bash
flutter gen-l10n
```

Add new user-facing strings to `app_en.arb` first, then add translations to the other locale files. Do not put localized text directly in Dart source files.

## Project structure

```text
lib/                    Flutter application
lib/l10n/               ARB resources and generated localization code
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
