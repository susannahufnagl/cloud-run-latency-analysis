#!/usr/bin/env bash
set -euo pipefail

# Stage 0: Cloud Run only, beide Endpunkte gleichzeitig pro Runde ---
: "${CR_BASE:?Setze CR_BASE, z.B. https://<dein-cloud-run>.run.app}"
: "${CE_BASE:?Setze CE_BASE, z.B. http://<ce-external-ip>:8080}"
: "${COUNT:=500}"       # Runden / Requests je Endpoint
: "${SLEEP:=0.2}"       # Pause zwischen Runden (Sekunden)
: "${TIMEOUT:=15}"      # curl Timeout pro Request


OUTDIR="${OUTDIR:-Testresults/S0}"

mkdir -p "$OUTDIR"
TS=$(date -u +%Y%m%dT%H%M%SZ)

CSV_CE_NB="${OUTDIR}/latencies_ce_nobatch_${TS}.csv"
CSV_CE_B="${OUTDIR}/latencies_ce_batch_${TS}.csv"

CSV_CR_NB="${OUTDIR}/latencies_cr_nobatch_${TS}.csv"
CSV_CR_B="${OUTDIR}/latencies_cr_batch_${TS}.csv"

echo "ts_iso,endpoint,http_status,client_total_ms,server_latency_ms,url" > "$CSV_CR_NB"
echo "ts_iso,endpoint,http_status,client_total_ms,server_latency_ms,url" > "$CSV_CR_B"
echo "ts_iso,endpoint,http_status,client_total_ms,server_latency_ms,url" > "$CSV_CE_NB"
echo "ts_iso,endpoint,http_status,client_total_ms,server_latency_ms,url" > "$CSV_CE_B"

cr_nobatch_url="${CR_BASE}/send/nobatch"
cr_batch_url="${CR_BASE}/send/batch"
ce_nobatch_url="${CE_BASE}/send/nobatch"
ce_batch_url="${CE_BASE}/send/batch"
#Warmup-wird nicht geloggt 
for _ in {1..10}; do
  curl -s -o /dev/null --max-time "$TIMEOUT" "$cr_nobatch_url" || true
  curl -s -o /dev/null --max-time "$TIMEOUT" "$cr_batch_url"   || true
  curl -s -o /dev/null --max-time "$TIMEOUT" "$ce_nobatch_url" || true
  curl -s -o /dev/null --max-time "$TIMEOUT" "$ce_batch_url"   || true
done

measure_one () {
  local name="$1" url="$2" csv="$3"
  local ts resp http total body client_ms server_ms
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  resp="$(curl -sS -H 'Connection: close' \
          -w ' HTTPSTATUS:%{http_code} TOTAL:%{time_total}' \
          --max-time "$TIMEOUT" "$url")" || true
  http="${resp##*HTTPSTATUS:}"; http="${http% TOTAL:*}"
  total="${resp##*TOTAL:}"
  body="${resp% HTTPSTATUS:*}"; body="${body% TOTAL:*}"
  client_ms=$(python3 - <<PY
try:
  print(round(float("$total")*1000,3))
except:
  print("")
PY
)
  if command -v jq >/dev/null 2>&1; then
    server_ms="$(echo "$body" | jq -r '.latency_ms // .latency_ms_nobatch // .latency_ms_batch // empty' 2>/dev/null || true)"
  else
    server_ms=""
  fi
  echo "$ts,$name,$http,$client_ms,$server_ms,$url" >> "$csv"
}

echo "Starte S0 (gleichzeitige Runden): COUNT=$COUNT, SLEEP=$SLEEP"
for i in $(seq 1 "$COUNT"); do
  #parallel abfeuern der endpunkte 
  measure_one "cr_nobatch" "$cr_nobatch_url" "$CSV_CR_NB" & # jede measure_one funtkion ruft intern curl auf, alle vier gleichzeitig 
  cr_pid_nb=$!
  measure_one "cr_batch"   "$cr_batch_url"   "$CSV_CR_B"  &
  cr_pid_b=$!
  measure_one "ce_nobatch" "$ce_nobatch_url" "$CSV_CE_NB" &
  ce_pid_nb=$!
  measure_one "ce_batch"   "$ce_batch_url"   "$CSV_CE_B"  &
  ce_pid_b=$!
  wait "$cr_pid_nb" "$cr_pid_b" "$ce_pid_nb" "$ce_pid_b" # warten bis alle veir fertig sind vor neuer runde 
  sleep "$SLEEP"
done

echo "Fertig:"
echo "  $CSV_CR_NB"
echo "  $CSV_CR_B"
echo "  $CSV_CE_NB"
echo "  $CSV_CE_B"
