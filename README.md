# thulium

Thulium is a cross-platform Flutter application for Tsinghua University
students. It uses [Forui](https://github.com/duobaseio/forui) for UI components
and reserves `packages/cli` for Dart command-line tools.

## Development

```bash
flutter pub get
flutter run -d chrome
```

Use Flutter `3.47.4`, matching the pinned Nix development environment, CI and
release workflows. Flutter's SDK packages constrain several test dependencies,
so a different SDK version may require changes to `pubspec.lock` and fail
`--enforce-lockfile`. The project currently uses Forui `0.22.x`.