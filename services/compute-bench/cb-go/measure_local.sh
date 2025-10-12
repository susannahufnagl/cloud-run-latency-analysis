#!/usr/bin/env bash
set -euo pipefail

RUN_URL="https://cloudrun-broker-single-997595983891.europe-west10.run.app"
OUT="latencies.csv"
COUNT=100       # Anzahl Messungen
SLEEP=0.2       # 0.2s = 5 RPS (konservativ, vermeidet Warteschlangen)

# Optionales Warmup (kannst du löschen, wenn du die ersten Samples später verwirfst)
for _ in {1..10}; do curl -s "$RUN_URL/send" >/dev/null || true; done

echo "timestamp_iso,iteration,http_status,latency_ms" > "$OUT"

for i in $(seq 1 "$COUNT"); do
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  RESP="$(curl -sS -w " HTTPSTATUS:%{http_code}" "$RUN_URL/send")"
  HTTP_CODE="${RESP##*HTTPSTATUS:}"
  JSON="${RESP% HTTPSTATUS:*}"
  LAT="$(echo "$JSON" | jq -r '.latency_ms // empty')"
  echo "$TS,$i,$HTTP_CODE,$LAT" >> "$OUT"
  sleep "$SLEEP"
done

echo "Fertig. Datei: $(pwd)/$OUT"
