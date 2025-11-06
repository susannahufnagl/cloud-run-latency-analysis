import pandas as pd
from pathlib import Path

paths = list(Path("Testresults").rglob("latencies_*.csv"))
rows = []
for p in paths:
    df = pd.read_csv(p)
    df = df[df["http_status"] == 200]
    rows.append({
        "stage": p.parts[1],  #z.B.S6_independent
        "kind": "client",
        "p50": df["client_total_ms"].quantile(0.5),
        "p95": df["client_total_ms"].quantile(0.95),
        "p99": df["client_total_ms"].quantile(0.99),
        "mean": df["client_total_ms"].mean(),
    })
    rows.append({
        "stage": p.parts[1],
        "kind": "server",
        "p50": df["server_latency_ms"].dropna().quantile(0.5),
        "p95": df["server_latency_ms"].dropna().quantile(0.95),
        "p99": df["server_latency_ms"].dropna().quantile(0.99),
        "mean": df["server_latency_ms"].dropna().mean(),
    })
summary = pd.DataFrame(rows)
summary.to_csv("results/stage_summary.csv", index=False)