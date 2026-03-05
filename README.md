![GHA workflow badge](https://github.com/AI-Smarties/front/actions/workflows/main.yml/badge.svg)

# AI-Smarties - Frontend (Flutter)

## Requirements

- Flutter **3.24.0** (stable) - Matches CI
- **Hardware** Even Realities G1 Smart Glasses

## Installation and setup

## 1. Clone repo and navigate to directory

```bash
    git clone git@github.com:AI-Smarties/front.git
```

```bash
    cd front
```

## 2. Switch to development branch (dev)

```bash
    git checkout dev
```

## 3. Confirm the Flutter environment

```bash
    flutter --version
```

```bash
    flutter doctor
```

> CI uses Flutter-version 3.24.0 (stable).

## 4. Install dependencies

```bash
    flutter pub get
```

## Environment variables

Create `config_dev.json` and `config_staging.json`:
Get an example of config\_\*.example.json files

```json
{
  "API_URL": "127.0.0.1:8000"
}
```

## 5.1 Start the application in Dev environment

```bash
    flutter run --dart-define-from-file=config_dev.json
```

## 5.2 or in Staging environment

```bash
    flutter run --dart-define-from-file=config_staging.json
```

## 5.3 If you're using VSC

You can start the program with `Ctrl + Shift + d` and select the environment in the upper left corner where the program will be started.

## Linting & formating (necessary in CI)

CI checks the formatting, analysis and tests.

Run locally:

```bash
    dart format --output=none --set-exit-if-changed .
```

```bash
    flutter analyze
```

```bash
    flutter test
```

Linting is enabled by adding
`very_good_analysis` and `analysis_options.yaml`.

---

## Daily development workflow

When you return to coding:

1. Fetch the latest changes:

```bash
    git checkout dev
```

```bash
    git pull origin dev
```

2. Install dependencies:

```bash
    flutter pub get
```

3. Run the application (For example in the dev environment):

```bash
    flutter run --dart-define-from-file=config_dev.json
```

4. Ensure CI-throughput before PR:

```bash
    dart format --output=none --set-exit-if-changed lib test
```

```bash
    flutter analyze
```

```bash
    flutter test
```

---
## Build app to android

run command

```bash
flutter build apk --dart-define-from-file=config_staging.json
```

then install it to usb connected android phone

```bash
flutter install
```

## Project structure (Flutter)

When `flutter create .` is run, the structure is typically:

- `lib/` – Application UI and application logic
- `test/` – Unit- and widget testing
- `android/`, `ios/` – Nativeprojects
- `.github/workflows/` – CI (format/analyze/test)
- `analysis_options.yaml` – lint-rules
- `pubspec.yaml` – Flutter/Dart dependencies

---

## About

Frontend for Everyday AI productivity interface for Even Realities G1 smart glasses.
