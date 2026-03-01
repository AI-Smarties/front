#!/bin/bash

# Valitsee konfiguraation argumentin perusteella
CONFIG="config_dev.json"
if [ "$1" == "staging" ]; then
  CONFIG="config_staging.json"
fi

echo "Käytetään konfiguraatiota: $CONFIG"

# Suodattaa turhat lokit
flutter run --dart-define-from-file=$CONFIG | grep -vE "GSC|VRI|BLAST|SurfaceView|InputMethod|FlutterJNI|IDS_TAG"