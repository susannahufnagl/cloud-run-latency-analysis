#!/usr/bin/env bash
set -euo pipefail

MINI_IP=$(minikube ip)
declare -a stages=(
  "4 http://$LB_IP"          #LB-Pfad (extern)
  "5 http://$MINI_IP:30082"  #runc NodePort
  "6 http://$MINI_IP:30083"  #gVisor NodePort
)

for entry in "${stages[@]}"; do
  read -r stage base <<<"$entry"
  CE_BASE="$base" STAGE="$stage" bash "$(dirname "$0")/run_all_concurrent_0.sh"
  CE_BASE="$base" STAGE="$stage" bash "$(dirname "$0")/run_all_independent_0.sh"
done