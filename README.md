![GHA workflow badge](https://github.com/AI-Smarties/front/actions/workflows/main.yml/badge.svg)

# AI-Smarties - Frontend (Flutter)

## Vaatimukset

- Flutter **3.24.0** (stable) - Matches CI
- **Laitteisto** Even Realities G1 Smart Glasses

## Asennus ja ajaminen

## 1. Kloonaa repo ja mene hakemistoon

```bash
    git clone git@github.com:AI-Smarties/front.git
```

```bash
    cd front
```

## 2. Vaihda kehityshaaraan (dev)

```bash
    git checkout dev
```

## 3. Varmista Flutter-ympäristö

```bash
    flutter --version
```

```bash
    flutter doctor
```

> CI käyttää Flutter-versiota 3.24.0 (stable).

## 4. Asenna riippuvuudet

```bash
    flutter pub get
```

## Ympäristömuuttujat

Luo `config_dev.json` ja `config_staging.json`:
Ota mallia config\_\*.example.json tiedostoista

```json
{
  "API_URL": "http://127.0.0.1:8000"
}
```

## 5.1 Käynnistä sovellus Dev ympäristössä

```bash
    flutter run --dart-define-from-file=config_dev.json
```

## 5.2 tai Staging ympäristössä

```bash
    flutter run --dart-define-from-file=config_staging.json
```

## 5.3 Jos käytät VSC

Voit käynnistää ohjelman `Ctrl + Shift + d` ja valitsemalla vasemmasta yläkulmasta ympäristön missä ohjelma käynnistetään

## Linttaus & formatointi (pakollinen CI:ssä)

CI tarkistaa formatoinnin, analyysin ja testit.

Aja paikallisesti:

```bash
    dart format --output=none --set-exit-if-changed .
```

```bash
    flutter analyze
```

```bash
    flutter test
```

Linttaus otetaan käyttöön lisäämällä `very_good_analysis` ja `analysis_options.yaml`.

---

## Päivittäinen kehitystyö

Kun palaat koodaamaan:

1. Hae uusimmat muutokset:

```bash
    git checkout dev
```

```bash
    git pull origin dev
```

2. Asenna riippuvuudet:

```bash
    flutter pub get
```

3. Aja sovellus (Esimerkiksi kehitysympäristössä):

```bash
    flutter run --dart-define-from-file=config_dev.json
```

4. Varmista CI-läpimeno ennen PR:ää:

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

## Projektin rakenne (Flutter)

Kun `flutter create .` on ajettu, rakenne on tyypillisesti:

- `lib/` – Sovelluksen UI ja sovelluslogiikka
- `test/` – Yksikkö- ja widget-testit
- `android/`, `ios/` – Natiiviprojektit
- `.github/workflows/` – CI (format/analyze/test)
- `analysis_options.yaml` – lint-säännöt
- `pubspec.yaml` – Flutter/Dart riippuvuudet

---

## Tietoa

Frontend for Everyday AI productivity interface for Even Realities G1 smart glasses.
