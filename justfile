FLUTTER := env_var_or_default("FLUTTER", "flutter")
DART := env_var_or_default("DART", "dart")

default:
    @just --list

flutter-deps:
    {{ FLUTTER }} pub get --enforce-lockfile

auth-deps:
    cd packages/auth && {{ DART }} pub get --enforce-lockfile

cli-deps:
    cd packages/cli && {{ DART }} pub get --enforce-lockfile

format-check:
    {{ DART }} format --output=none --set-exit-if-changed lib test packages/auth/lib packages/auth/test packages/cli/bin packages/cli/lib

flutter-analyze:
    {{ FLUTTER }} analyze

flutter-test:
    {{ FLUTTER }} test

auth-analyze:
    cd packages/auth && {{ DART }} analyze

auth-test:
    cd packages/auth && {{ DART }} test

cli-analyze:
    cd packages/cli && {{ DART }} analyze

ci: flutter-deps auth-deps cli-deps format-check flutter-analyze flutter-test auth-analyze auth-test cli-analyze

build-android-release: flutter-deps
    {{ FLUTTER }} build apk --release --split-per-abi

build-ios-release: flutter-deps
    {{ FLUTTER }} build ios --release --no-codesign

build-linux-release: flutter-deps
    {{ FLUTTER }} build linux --release

build-windows-release: flutter-deps
    {{ FLUTTER }} build windows --release

build-macos-release: flutter-deps
    {{ FLUTTER }} build macos --release

build-cli output: cli-deps
    cd packages/cli && {{ DART }} compile exe bin/thulium.dart -o {{ output }}
