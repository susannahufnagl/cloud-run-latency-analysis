set -euo pipefail

# Default-Werte
: "${MODE:=warm}"
: "${OUTDIR:=../results}"
: "${RUNS:=200}"
: "${SLEEP_MS:=50}"
: "${TIMEOUT:=15}"

mkdir -p "$OUTDIR"

CSV_FILE="${OUTDIR}/latencies_${MODE}_$(date +%Y%m%d-%H%M%S).csv"

echo "timestamp,platform,endpoint,latency_ms,status" > "$CSV_FILE"

echo "Starting benchmark: MODE=$MODE RUNS=$RUNS"

# Schleife über alle Endpunkte
for endpoint in "/send/nobatch" "/send/batch"; do
  for i in $(seq 1 $RUNS); do
    t0=$(date +%s%3N)
    # CE-Aufruf
    ce_resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "${CE_BASE}${endpoint}" || echo "000")
    t1=$(date +%s%3N)
    ce_lat=$((t1 - t0))
    echo "$(date +%s%3N),CE,${endpoint},${ce_lat},${ce_resp}" >> "$CSV_FILE"

    # CR-Aufruf
    t0=$(date +%s%3N)
    cr_resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "${CR_BASE}${endpoint}" || echo "000")
    t1=$(date +%s%3N)
    cr_lat=$((t1 - t0))
    echo "$(date +%s%3N),CR,${endpoint},${cr_lat},${cr_resp}" >> "$CSV_FILE"

    # kurze Pause
    sleep $(bc <<< "scale=3; ${SLEEP_MS}/1000")
  done
done

echo "Benchmark complete → $CSV_FILE"
