import requests
import time
import csv
from datetime import datetime


GO_URL = "https://cloudrun-broker-single-go-cb2s6gb3jq-oe.a.run.app/send/nobatch"
PY_URL = "https://cloudrun-broker-single-py-cb2s6gb3jq-oe.a.run.app/send"

#wie viele Messungen 
N = 500

def measure(url, outfile, latency_field):
    rows = []
  
    requests.get(url)
    for i in range(N):
        r = requests.get(url)
        if r.ok:
            data = r.json()
            rows.append([datetime.now().isoformat(), data.get("cold_start"), data.get(latency_field)])
        else:
            rows.append([datetime.now().isoformat(), None, None])
        if i % 50 == 0:
            print(f"{outfile}: {i} done")

    with open(outfile, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["ts", "cold_start", "server_ms"])
        w.writerows(rows)

if __name__ == "__main__":
    measure(GO_URL, "go_nobatch_500.csv", "latency_ms_nobatch")
    measure(PY_URL, "py_nobatch_500.csv", "latency_ms")  # ggf. latency_ms_nobatch