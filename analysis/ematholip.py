#!/usr/bin/env python3
"""
Generate detailed latency summaries and plots across all recorded measurement runs.
The script inspects every `latencies_*.csv` under `Testresults/`, derives metadata
from the folder hierarchy (stage, run timestamp, run id, workload kind), computes
per-run statistics, aggregates them per category, and finally calculates phase deltas
plus several boxplots to visualize the spread of client/server latencies.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns


STAGE_RE = re.compile(r"^(?P<label>S(?P<num>\d+))_(?P<mode>[A-Za-z0-9-]+)$")
RUN_RE = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})_(?P<time>\d{2}-\d{2}-\d{2})_run-(?P<run_id>[0-9A-Za-z-]+)$"
)
FILE_RE = re.compile(
    r"^latencies_(?P<workload>[A-Za-z0-9-]+(?:_[A-Za-z0-9-]+)*)_(?P<date>\d{4}-\d{2}-\d{2})_(?P<time>\d{2}-\d{2}-\d{2})$"
)


@dataclass(frozen=True)
class FileMetadata:
    csv_path: Path
    stage_label: str
    stage_num: int
    mode: str
    run_folder: str
    run_id: str
    run_started_at: datetime
    workload: str
    file_started_at: datetime


def parse_metadata(csv_path: Path) -> FileMetadata:
    try:
        stage_match = STAGE_RE.match(csv_path.parents[2].name)
    except IndexError as exc:  # pragma: no cover - guard against odd layouts
        raise ValueError(f"Unexpected directory layout for {csv_path}") from exc
    if not stage_match:
        raise ValueError(f"Cannot parse stage info from {csv_path}")

    run_match = RUN_RE.match(csv_path.parents[1].name)
    if not run_match:
        raise ValueError(f"Cannot parse run info from {csv_path}")

    file_match = FILE_RE.match(csv_path.stem)
    if not file_match:
        raise ValueError(f"Cannot parse workload info from {csv_path.name}")

    run_started = datetime.fromisoformat(
        f"{run_match['date']}T{run_match['time'].replace('-', ':')}"
    )
    file_started = datetime.fromisoformat(
        f"{file_match['date']}T{file_match['time'].replace('-', ':')}"
    )

    return FileMetadata(
        csv_path=csv_path,
        stage_label=stage_match["label"],
        stage_num=int(stage_match["num"]),
        mode=stage_match["mode"],
        run_folder=csv_path.parents[1].name,
        run_id=run_match["run_id"],
        run_started_at=run_started,
        workload=file_match["workload"],
        file_started_at=file_started,
    )


def series_stats(series: pd.Series, prefix: str) -> dict[str, float]:
    clean = series.dropna()
    if clean.empty:
        return {f"{prefix}_{name}": None for name in ("count", "mean", "p50", "p95", "p99", "min", "max")}
    return {
        f"{prefix}_count": float(clean.count()),
        f"{prefix}_mean": float(clean.mean()),
        f"{prefix}_p50": float(clean.quantile(0.5)),
        f"{prefix}_p95": float(clean.quantile(0.95)),
        f"{prefix}_p99": float(clean.quantile(0.99)),
        f"{prefix}_min": float(clean.min()),
        f"{prefix}_max": float(clean.max()),
    }


def gather_records(csv_paths: Iterable[Path]) -> tuple[pd.DataFrame, pd.DataFrame]:
    records: list[dict] = []
    sample_frames: list[pd.DataFrame] = []
    for csv_path in sorted(csv_paths):
        meta = parse_metadata(csv_path)
        df = pd.read_csv(csv_path)
        df["ts_iso"] = pd.to_datetime(df.get("ts_iso"))
        total_count = len(df)
        success = df[df["http_status"] == 200]
        server_stats = series_stats(success["server_latency_ms"], "server")
        client_stats = series_stats(success["client_total_ms"], "client")
        record = {
            "csv_path": str(csv_path),
            "stage_label": meta.stage_label,
            "stage_num": meta.stage_num,
            "mode": meta.mode,
            "workload": meta.workload,
            "run_folder": meta.run_folder,
            "run_id": meta.run_id,
            "run_started_at": meta.run_started_at.isoformat(),
            "file_started_at": meta.file_started_at.isoformat(),
            "total_samples": total_count,
            "successful_samples": int(success.shape[0]),
            "error_rate": float(1 - (success.shape[0] / total_count)) if total_count else None,
            "ts_first": success["ts_iso"].min().isoformat() if not success["ts_iso"].isna().all() else None,
            "ts_last": success["ts_iso"].max().isoformat() if not success["ts_iso"].isna().all() else None,
        }
        record.update(client_stats)
        record.update(server_stats)
        records.append(record)

        sample_subset = success[["client_total_ms", "server_latency_ms"]].copy()
        sample_subset["stage_num"] = meta.stage_num
        sample_subset["stage_label"] = meta.stage_label
        sample_subset["mode"] = meta.mode
        sample_subset["workload"] = meta.workload
        sample_frames.append(sample_subset)

    run_summary = pd.DataFrame(records)
    samples = pd.concat(sample_frames, ignore_index=True) if sample_frames else pd.DataFrame()
    return run_summary, samples


def aggregate_categories(run_summary: pd.DataFrame) -> pd.DataFrame:
    key_cols = ["stage_num", "stage_label", "mode", "workload"]
    metric_cols = [
        col
        for col in run_summary.columns
        if col.startswith(("client_", "server_")) and col.endswith(("mean", "p50", "p95", "p99"))
    ]

    agg_map = {col: ["mean", "std"] for col in metric_cols}
    agg_map.update({"successful_samples": ["mean"], "error_rate": ["mean"]})

    grouped = run_summary.groupby(key_cols).agg(agg_map)
    grouped.columns = ["{}_{}".format(col, stat) for col, stat in grouped.columns]
    return grouped.reset_index()


def compute_phase_deltas(category_summary: pd.DataFrame) -> pd.DataFrame:
    metric_cols = [c for c in category_summary.columns if c.startswith(("client_", "server_"))]
    delta_frames = []
    for (mode, workload), group in category_summary.groupby(["mode", "workload"]):
        sorted_group = group.sort_values("stage_num").copy()
        for col in metric_cols:
            sorted_group[f"{col}_delta_prev"] = sorted_group[col].diff()
            sorted_group[f"{col}_delta_from_s0"] = sorted_group[col] - sorted_group[col].iloc[0]
        delta_frames.append(sorted_group)
    return pd.concat(delta_frames, ignore_index=True) if delta_frames else pd.DataFrame()


def plot_boxplots(samples: pd.DataFrame, out_dir: Path) -> list[Path]:
    if samples.empty:
        return []
    out_dir.mkdir(parents=True, exist_ok=True)
    figure_paths: list[Path] = []
    sns.set_theme(style="whitegrid")
    for metric, column in (("client", "client_total_ms"), ("server", "server_latency_ms")):
        for workload in sorted(samples["workload"].unique()):
            data = samples[(samples["workload"] == workload) & samples[column].notna()]
            if data.empty:
                continue
            plt.figure(figsize=(10, 6))
            sns.boxplot(
                data=data,
                x="stage_num",
                y=column,
                hue="mode",
                palette="Set2",
            )
            plt.title(f"{metric.title()} latency distribution – {workload}")
            plt.xlabel("Stage")
            plt.ylabel("Latency (ms)")
            plt.tight_layout()
            fig_path = out_dir / f"boxplot_{metric}_{workload}.png"
            plt.savefig(fig_path, dpi=200)
            plt.close()
            figure_paths.append(fig_path)
    return figure_paths


def main() -> None:
    parser = argparse.ArgumentParser(description="Compute latency summaries and plots.")
    parser.add_argument(
        "--testresults-root",
        default="Testresults",
        help="Directory that contains the stage sub-folders (default: %(default)s)",
    )
    parser.add_argument(
        "--output-dir",
        default="results/ematholip",
        help="Directory to write csv/json summaries and plots (default: %(default)s)",
    )
    args = parser.parse_args()

    testresults_path = Path(args.testresults_root)
    if not testresults_path.exists():
        raise SystemExit(f"{testresults_path} does not exist")
    csv_paths = list(testresults_path.rglob("latencies_*.csv"))
    if not csv_paths:
        raise SystemExit(f"No latency csv files found under {testresults_path}")

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    run_summary, samples = gather_records(csv_paths)
    run_summary.sort_values(["stage_num", "mode", "workload", "run_folder"], inplace=True)
    run_summary.to_csv(output_dir / "run_summary.csv", index=False)

    category_summary = aggregate_categories(run_summary)
    category_summary.to_csv(output_dir / "category_summary.csv", index=False)

    phase_deltas = compute_phase_deltas(category_summary)
    phase_deltas.to_csv(output_dir / "phase_deltas.csv", index=False)

    figures_dir = output_dir / "figures"
    saved_figures = plot_boxplots(samples, figures_dir)

    manifest = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "run_summary": str((output_dir / "run_summary.csv").resolve()),
        "category_summary": str((output_dir / "category_summary.csv").resolve()),
        "phase_deltas": str((output_dir / "phase_deltas.csv").resolve()),
        "figures": [str(path.resolve()) for path in saved_figures],
    }
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
