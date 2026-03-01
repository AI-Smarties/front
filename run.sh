#!/bin/bash

CONFIG="config_dev.json"
[ "$1" == "staging" ] && CONFIG="config_staging.json"

echo "Käytetään konfiguraatiota: $CONFIG"

flutter run --dart-define-from-file=$CONFIG 2>&1 \
| grep -E "E/flutter|Unhandled Exception"
