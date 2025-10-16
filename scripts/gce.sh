set -euo pipefail
if [ -f ".env" ]; then
  # nur bekannte Variablen erlauben
  set -a
  source .env
  set +a
fi

PROJECT="${PROJECT:-project-accountsec}"
ZONE="${ZONE:-europe-west10-b}"
INSTANCE="${INSTANCE:-ce-latency-bench}"

start()  { gcloud compute instances start "$INSTANCE" --zone "$ZONE" --project "$PROJECT"; }
stop()   { gcloud compute instances stop  "$INSTANCE" --zone "$ZONE" --project "$PROJECT"; }
ssh()    { gcloud compute ssh "$INSTANCE" --zone "$ZONE" --project "$PROJECT" -- ${*:-bash}; }
ip()     { gcloud compute instances describe "$INSTANCE" --zone "$ZONE" --project "$PROJECT" \
            --format='get(networkInterfaces[0].accessConfigs[0].natIP)'; }
health() { gcloud compute ssh "$INSTANCE" --zone "$ZONE" --project "$PROJECT" \
            --command "curl -fsS http://127.0.0.1:8080/health || echo FAIL"; }
up()     { start && sleep 3 && ip; }

case "${1:-}" in
  start|stop|ssh|ip|health|up) "$@";;
  *) echo "usage: $0 {start|stop|ssh|ip|health|up}" >&2; exit 1;;
esac
