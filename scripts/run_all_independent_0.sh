# --- anstelle der bisherigen "for i in seq 1 $COUNT" Schleife: ---
#!/usr/bin/env bash
set -euo pipefail

# Stage 0: Cloud Run only, beide Endpunkte gleichzeitig pro Runde ---
: "${CR_BASE:?Setze CR_BASE, z.B. https://<dein-cloud-run>.run.app}"
: "${CE_BASE:?Setze CE_BASE, z.B. http://<ce-external-ip>:8080}"
: "${COUNT:=500}"       # Runden / Requests je Endpoint
: "${SLEEP:=0.2}"       # Pause zwischen Runden (Sekunden)
: "${TIMEOUT:=15}"      # curl Timeout pro Request


OUTDIR="${OUTDIR:-Testresults/S0_independent}"

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
stream_endpoint() { # name url csv
  local name="$1" url="$2" csv="$3"
  for i in $(seq 1 "$COUNT"); do
    measure_one "$name" "$url" "$csv"
    # optional: Mikropause, um zu "entstauen" – sonst weglassen
    # sleep "$SLEEP"
  done
}

echo "Starte Streams: je Endpoint $COUNT Requests back-to-back (keine Runden, kein Warten)"
#vier unabhängige Streams gleichzeitig starten
stream_endpoint "cr_nobatch" "$cr_nobatch_url" "$CSV_CR_NB" &
pid_cr_nb=$!
stream_endpoint "cr_batch"   "$cr_batch_url"   "$CSV_CR_B"  &
pid_cr_b=$!
stream_endpoint "ce_nobatch" "$ce_nobatch_url" "$CSV_CE_NB" &
pid_ce_nb=$!
stream_endpoint "ce_batch"   "$ce_batch_url"   "$CSV_CE_B"  &
pid_ce_b=$!

#auf alle vier Streams warten
wait "$pid_cr_nb" "$pid_cr_b" "$pid_ce_nb" "$pid_ce_b"

echo "Fertig:"
echo "  $CSV_CR_NB"
echo "  $CSV_CR_B"
echo "  $CSV_CE_NB"
echo "  $CSV_CE_B"
