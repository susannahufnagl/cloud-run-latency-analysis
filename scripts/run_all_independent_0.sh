#!/usr/bin/env bash
set -euo pipefail


STAGE="${STAGE:-0}"  
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a || true

# if [[ -z "${CE_BASE:-}" ]]; then
#   case "$STAGE" in
#     0) CE_BASE= "http://127.0.0.1:8080" ;;
#     # ;;   # Stufe 1 => localhost
#     # optional weitere Defaults:
#     # 2) CE_BASE="http://10.0.0.2:8080" ;;
#     # 3) CE_BASE="http://34.32.11.63:8080" ;;
#     *) : ;;  # für andere Stages kein Auto-Default
#   esac
# fi

BASE_RESULTS_DIR="${BASE_RESULTS_DIR:-$REPO_ROOT/Testresults}"
STAGE_LABEL="${STAGE_LABEL:-S${STAGE}_independent}" 
TS_UTC="$(date -u +"%Y-%m-%d_%H-%M-%S")"
RUN_ID="$(printf 'run-%04d' $(( RANDOM % 10000 )))"   #oder zähler, s.u.
OUTDIR="${BASE_RESULTS_DIR}/${STAGE_LABEL}/${TS_UTC}_${RUN_ID}"
CHANNEL="${CHANNEL:-node}"
mkdir -p "$OUTDIR"

#Index-Datei
MASTER_INDEX="${BASE_RESULTS_DIR}/index.csv"
if [[ ! -f "$MASTER_INDEX" ]]; then
  echo "ts_utc,stage,run_id,dir,project,instance,zone,count,sleep,timeout,ce_base,cr_base,channel" > "$MASTER_INDEX"
fi


#Stage 0: Cloud Run only, beide Endpunkte gleichzeitig pro Runde 
: "${CR_BASE:?Setze CR_BASE, z.B. https://cloudrun-broker-single-go-997595983891.europe-west10.run.app}"
: "${CE_BASE:?Setze CE_BASE, z.B. http://:8080}"
: "${COUNT:=500}"       #Runden/Requests je Endpoint
: "${SLEEP:=0.2}"       #Pause zwischen Runden(Sekunden)
: "${TIMEOUT:=15}"      #curl Timeout pro Request



CSV_CE_NB="${OUTDIR}/latencies_ce_nobatch_${TS_UTC}.csv"
CSV_CE_B="${OUTDIR}/latencies_ce_batch_${TS_UTC}.csv"

CSV_CR_NB="${OUTDIR}/latencies_cr_nobatch_${TS_UTC}.csv"
CSV_CR_B="${OUTDIR}/latencies_cr_batch_${TS_UTC}.csv"

echo "ts_iso,endpoint,http_status,client_total_ms,server_latency_ms,url,cold_start" > "$CSV_CR_NB"
echo "ts_iso,endpoint,http_status,client_total_ms,server_latency_ms,url,cold_start" > "$CSV_CR_B"
echo "ts_iso,endpoint,http_status,client_total_ms,server_latency_ms,url,cold_start" > "$CSV_CE_NB"
echo "ts_iso,endpoint,http_status,client_total_ms,server_latency_ms,url,cold_start" > "$CSV_CE_B"


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
  local ts resp http total body client_ms server_ms cold
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
  server_ms=""; cold=""
  if command -v jq >/dev/null 2>&1; then
    server_ms="$(echo "$body" | jq -r '.latency_ms // .latency_ms_nobatch // .latency_ms_batch // empty' 2>/dev/null || true)"
    cold="$(echo "$body" | jq -r '.cold_start // empty' 2>/dev/null || true)"
    

  else
    server_ms=""
  fi
  echo "$ts,$name,$http,$client_ms,$server_ms,$url,$cold" >> "$csv"
# echo "$ts,$name,$http,$client_ms,$server_ms,$url" >> "$csv"
}
stream_endpoint() { #name url csv
  local name="$1" url="$2" csv="$3"
  for i in $(seq 1 "$COUNT"); do
    measure_one "$name" "$url" "$csv"
    
    # sleep "$SLEEP"
  done
}
# open closed workload nachschauen und einbinden 
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
# pro endpoint ein eigener stream von count requets ohne sleep, alle vier streams laufen parallel 
#auf alle vier Streams warten
wait "$pid_cr_nb" "$pid_cr_b" "$pid_ce_nb" "$pid_ce_b"

echo "Fertig:"
echo "  $CSV_CR_NB"
echo "  $CSV_CR_B"
echo "  $CSV_CE_NB"
echo "  $CSV_CE_B"


set -a; source "$REPO_ROOT/.env"; set +a 2>/dev/null || true
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),${STAGE_LABEL},${RUN_ID},${OUTDIR},${PROJECT:-},${INSTANCE:-},${ZONE:-},${COUNT:-},${SLEEP:-},${TIMEOUT:-},${CE_BASE:-},${CR_BASE:-}" \
  >> "$MASTER_INDEX"
