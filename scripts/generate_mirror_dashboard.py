"""Generate a local HTML dashboard for mirror progress.

By default this script writes ``var/site_mirror/dashboard.html`` once.
With ``--watch-seconds`` it keeps regenerating the page periodically so the
HTML can be reloaded in the browser during a long mirror run.
"""

from __future__ import annotations

import argparse
import html
import json
import subprocess
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SITE_MIRROR_ROOT = ROOT / "var" / "site_mirror"
BATCH_LOG = SITE_MIRROR_ROOT / "batch_logs" / "batch.log"
OUTPUT_PATH = SITE_MIRROR_ROOT / "dashboard.html"
SITE_ORDER = [
    "kanjidraw",
    "the_kanji_map",
    "kanshudo",
    "wanikani",
    "tanoshii_japanese",
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH)
    parser.add_argument("--watch-seconds", type=float, default=None)
    args = parser.parse_args()

    if args.watch_seconds and args.watch_seconds > 0:
        while True:
            write_dashboard(args.output)
            time.sleep(args.watch_seconds)
    write_dashboard(args.output)
    return 0


def write_dashboard(output_path: Path) -> None:
    snapshot = collect_snapshot()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(render_html(snapshot), encoding="utf-8")
    print(f"Wrote {output_path}")


def collect_snapshot() -> dict[str, Any]:
    batch_events = parse_batch_log(BATCH_LOG)
    sites = []
    active_sites = []
    total_ok = 0
    total_errors = 0
    total_saved = 0
    for index, site_id in enumerate(SITE_ORDER, start=1):
        site_data = collect_site(site_id)
        site_data["position"] = index
        sites.append(site_data)
        if site_data["status"] == "running":
            active_sites.append(site_id)
        total_ok += site_data["ok_count"]
        total_errors += site_data["error_count"]
        total_saved += site_data["saved_count"]

    done_count = sum(1 for site in sites if site["status"] == "done")
    return {
        "generated_at": iso_now(),
        "batch_events": batch_events,
        "active_sites": active_sites,
        "sites": sites,
        "done_count": done_count,
        "site_count": len(SITE_ORDER),
        "total_ok": total_ok,
        "total_errors": total_errors,
        "total_saved": total_saved,
    }


def collect_site(site_id: str) -> dict[str, Any]:
    site_root = SITE_MIRROR_ROOT / site_id
    summary_path = site_root / "summary.json"
    fetch_log_path = site_root / "fetch_log.jsonl"
    mirror_root = site_root / "mirror"
    runner_path = site_root / "runner.json"

    summary = read_json(summary_path)
    runner = read_json(runner_path)
    last_event = None
    ok_count = 0
    error_count = 0
    skipped_count = 0
    events_total = 0
    pages_count = 0
    assets_count = 0
    saved_paths: dict[str, int] = {}
    start_at = parse_iso(runner.get("start_at"))
    end_at = parse_iso(runner.get("end_at"))
    site_started = bool(start_at)
    if fetch_log_path.exists():
        with fetch_log_path.open(encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    payload = json.loads(line)
                except json.JSONDecodeError:
                    continue
                fetched_at = parse_iso(payload.get("fetched_at") or payload.get("timestamp"))
                if site_started:
                    if fetched_at is None or fetched_at < start_at:
                        continue
                    if end_at is not None and fetched_at > end_at:
                        continue
                else:
                    continue
                events_total += 1
                last_event = payload
                status = payload.get("status")
                if isinstance(status, int) and 200 <= status < 400:
                    ok_count += 1
                    saved_path = payload.get("saved_path")
                    if isinstance(saved_path, str):
                        saved_paths[saved_path] = 1
                    content_type = str(payload.get("content_type", ""))
                    if content_type.startswith("text/html"):
                        pages_count += 1
                    else:
                        assets_count += 1
                elif status == "skipped":
                    skipped_count += 1
                else:
                    error_count += 1

    saved_files = 0
    saved_bytes = 0
    for saved_path in saved_paths:
        path = Path(saved_path)
        if not path.exists() or not path.is_file():
            continue
        saved_files += 1
        try:
            saved_bytes += path.stat().st_size
        except OSError:
            continue

    return {
        "id": site_id,
        "status": resolve_site_status(runner, summary, start_at),
        "runner": runner,
        "summary": summary,
        "summary_path": rel_path(summary_path),
        "fetch_log_path": rel_path(fetch_log_path),
        "mirror_path": rel_path(mirror_root),
        "runner_path": rel_path(runner_path),
        "events_total": events_total,
        "ok_count": ok_count,
        "error_count": error_count,
        "skipped_count": skipped_count,
        "pages_count": pages_count,
        "assets_count": assets_count,
        "total_count": events_total,
        "saved_files": saved_files,
        "saved_count": len(saved_paths),
        "saved_bytes": saved_bytes,
        "last_event": last_event,
        "start_at": runner.get("start_at"),
        "end_at": runner.get("end_at"),
    }


def parse_batch_log(path: Path) -> list[dict[str, str]]:
    events = []
    if not path.exists():
        return events
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split()
        if len(parts) != 3:
            continue
        timestamp, action, site = parts
        events.append({"timestamp": timestamp, "action": action, "site": site})
    return events


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError:
        return {}


def rel_path(path: Path) -> str:
    try:
        return path.relative_to(SITE_MIRROR_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def fmt_bytes(value: int) -> str:
    units = ["B", "KB", "MB", "GB"]
    size = float(value)
    for unit in units:
        if size < 1024 or unit == units[-1]:
            return f"{size:.1f} {unit}" if unit != "B" else f"{int(size)} {unit}"
        size /= 1024
    return f"{value} B"


def fmt_time(value: str | None) -> str:
    if not value:
        return "n/a"
    dt = parse_iso(value)
    if dt is None:
        return value
    return dt.astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")


def iso_now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


def parse_iso(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def resolve_site_status(runner: dict[str, Any], summary: dict[str, Any], start_at: datetime | None) -> str:
    if not runner:
        return "pending"
    status = str(runner.get("status") or "").lower()
    pid = runner.get("pid")
    completed_at = parse_iso(summary.get("completed_at"))
    if status == "done":
        return "done"
    if status == "failed":
        return "failed"
    if isinstance(pid, int) and process_exists(pid):
        return "running"
    if start_at and completed_at and completed_at >= start_at:
        return "done"
    return "stopped"


def process_exists(pid: int) -> bool:
    result = subprocess.run(
        ["tasklist", "/FI", f"PID eq {pid}", "/FO", "CSV", "/NH"],
        capture_output=True,
        text=True,
        check=False,
    )
    output = result.stdout.strip()
    if not output or output.startswith("INFO:"):
        return False
    return f'"{pid}"' in output


def render_html(snapshot: dict[str, Any]) -> str:
    done = snapshot["done_count"]
    total = snapshot["site_count"]
    progress = int((done / total) * 100) if total else 0
    active_sites = snapshot["active_sites"]
    active_label = ", ".join(active_sites) if active_sites else "idle"
    site_cards = "\n".join(render_site_card(site) for site in snapshot["sites"])
    timeline = "\n".join(render_event(event) for event in snapshot["batch_events"][-12:]) or "<li>No batch events yet.</li>"
    return f"""<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="20">
  <title>Mirror Progress</title>
  <style>
    :root {{
      --bg: #f2ede4;
      --ink: #16211b;
      --muted: #5c6d62;
      --card: rgba(255,255,255,0.72);
      --line: rgba(22,33,27,0.14);
      --accent: #b5442a;
      --accent-soft: #e9b89b;
      --green: #2d6a4f;
      --amber: #a56216;
      --slate: #3b4a43;
      --shadow: 0 18px 40px rgba(22,33,27,0.08);
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: Georgia, "Times New Roman", serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(181,68,42,0.18), transparent 28rem),
        radial-gradient(circle at top right, rgba(45,106,79,0.14), transparent 22rem),
        linear-gradient(180deg, #f7f2ea 0%, var(--bg) 100%);
    }}
    .shell {{
      max-width: 1180px;
      margin: 0 auto;
      padding: 32px 20px 56px;
    }}
    .hero {{
      display: grid;
      grid-template-columns: 1.5fr 1fr;
      gap: 18px;
      align-items: stretch;
      margin-bottom: 22px;
    }}
    .panel {{
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 24px;
      box-shadow: var(--shadow);
      backdrop-filter: blur(10px);
    }}
    .hero-main {{
      padding: 28px;
      position: relative;
      overflow: hidden;
    }}
    .hero-main::after {{
      content: "";
      position: absolute;
      inset: auto -10% -35% auto;
      width: 280px;
      height: 280px;
      border-radius: 999px;
      background: radial-gradient(circle, rgba(181,68,42,0.18), rgba(181,68,42,0) 70%);
    }}
    h1 {{
      margin: 0 0 8px;
      font-size: clamp(2rem, 4vw, 3.6rem);
      line-height: 0.95;
      letter-spacing: -0.04em;
    }}
    .lede {{
      margin: 0 0 18px;
      font-size: 1rem;
      color: var(--muted);
      max-width: 56ch;
    }}
    .kpis {{
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 10px;
    }}
    .kpi {{
      padding: 14px 16px;
      background: rgba(255,255,255,0.7);
      border-radius: 16px;
      border: 1px solid rgba(22,33,27,0.08);
    }}
    .kpi .label {{
      display: block;
      color: var(--muted);
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      margin-bottom: 8px;
    }}
    .kpi .value {{
      display: block;
      font-size: 1.5rem;
      font-weight: bold;
    }}
    .hero-side {{
      padding: 24px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      gap: 18px;
      background:
        linear-gradient(180deg, rgba(255,255,255,0.74), rgba(255,255,255,0.62)),
        repeating-linear-gradient(-45deg, rgba(22,33,27,0.025), rgba(22,33,27,0.025) 8px, transparent 8px, transparent 16px);
    }}
    .progress-wrap {{
      height: 16px;
      border-radius: 999px;
      background: rgba(22,33,27,0.08);
      overflow: hidden;
      border: 1px solid rgba(22,33,27,0.06);
    }}
    .progress-bar {{
      height: 100%;
      width: {progress}%;
      background: linear-gradient(90deg, var(--accent), #d26d4e, #efb38f);
      transition: width 0.4s ease;
    }}
    .side-note {{
      margin: 0;
      color: var(--muted);
      font-size: 0.96rem;
      line-height: 1.45;
    }}
    .grid {{
      display: grid;
      grid-template-columns: 1.2fr 0.8fr;
      gap: 18px;
    }}
    .sites {{
      display: grid;
      gap: 14px;
    }}
    .site-card {{
      padding: 18px 18px 16px;
      display: grid;
      gap: 12px;
    }}
    .site-top {{
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: start;
    }}
    .site-name {{
      margin: 0;
      font-size: 1.24rem;
    }}
    .site-sub {{
      margin: 4px 0 0;
      color: var(--muted);
      font-size: 0.92rem;
    }}
    .badge {{
      white-space: nowrap;
      border-radius: 999px;
      padding: 7px 10px;
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      border: 1px solid rgba(22,33,27,0.1);
      background: rgba(255,255,255,0.74);
    }}
    .badge.running {{ color: white; background: var(--accent); border-color: transparent; }}
    .badge.done {{ color: white; background: var(--green); border-color: transparent; }}
    .badge.pending {{ color: var(--slate); }}
    .badge.paused, .badge.started, .badge.stopped {{ color: white; background: var(--amber); border-color: transparent; }}
    .badge.failed {{ color: white; background: #8f1d2c; border-color: transparent; }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(4, minmax(0,1fr));
      gap: 10px;
    }}
    .stat {{
      background: rgba(255,255,255,0.72);
      border: 1px solid rgba(22,33,27,0.08);
      border-radius: 14px;
      padding: 10px 12px;
    }}
    .stat .small {{
      display: block;
      color: var(--muted);
      font-size: 0.76rem;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      margin-bottom: 5px;
    }}
    .stat .big {{
      display: block;
      font-size: 1.08rem;
      font-weight: bold;
    }}
    .links, .meta {{
      display: flex;
      flex-wrap: wrap;
      gap: 10px 14px;
      font-size: 0.92rem;
    }}
    a {{
      color: var(--accent);
      text-decoration: none;
    }}
    a:hover {{ text-decoration: underline; }}
    .timeline {{
      padding: 20px;
    }}
    .timeline h2, .sites-head {{
      margin: 0 0 12px;
      font-size: 1.1rem;
      letter-spacing: 0.02em;
    }}
    ol {{
      margin: 0;
      padding-left: 18px;
    }}
    li {{
      margin-bottom: 10px;
      color: var(--muted);
      line-height: 1.4;
    }}
    code {{
      font-family: "Cascadia Code", "SFMono-Regular", Consolas, monospace;
      font-size: 0.9em;
      background: rgba(22,33,27,0.06);
      border-radius: 6px;
      padding: 1px 5px;
    }}
    @media (max-width: 980px) {{
      .hero, .grid {{ grid-template-columns: 1fr; }}
      .kpis, .stats {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }}
    }}
    @media (max-width: 640px) {{
      .shell {{ padding: 18px 12px 36px; }}
      .hero-main, .hero-side, .timeline {{ padding: 18px; }}
      .kpis, .stats {{ grid-template-columns: 1fr; }}
      .site-top {{ flex-direction: column; }}
    }}
  </style>
</head>
<body>
  <div class="shell">
    <section class="hero">
      <div class="panel hero-main">
        <h1>Mirror Progress</h1>
        <p class="lede">Tableau local généré depuis les logs de crawl. La page se recharge toutes les 20 secondes. Les données sont régénérées par un watcher séparé.</p>
        <div class="kpis">
          <div class="kpi"><span class="label">Batch</span><span class="value">{done}/{total}</span></div>
          <div class="kpi"><span class="label">Active Sites</span><span class="value">{html.escape(active_label)}</span></div>
          <div class="kpi"><span class="label">OK Requests</span><span class="value">{snapshot["total_ok"]}</span></div>
          <div class="kpi"><span class="label">Running Workers</span><span class="value">{len(active_sites)}</span></div>
        </div>
      </div>
      <aside class="panel hero-side">
        <div>
          <p class="side-note"><strong>Dernière génération</strong><br>{html.escape(fmt_time(snapshot["generated_at"]))}</p>
        </div>
        <div>
          <div class="progress-wrap"><div class="progress-bar"></div></div>
          <p class="side-note" style="margin-top:10px;">Progression de batch: <strong>{progress}%</strong>. Erreurs vues: <strong>{snapshot["total_errors"]}</strong>. Fichiers sauvés: <strong>{snapshot["total_saved"]}</strong>.</p>
        </div>
        <p class="side-note">Fichier source principal: <a href="batch_logs/batch.log">batch_logs/batch.log</a></p>
      </aside>
    </section>

    <section class="grid">
      <div class="sites">
        <div class="sites-head">Sites</div>
        {site_cards}
      </div>
      <aside class="panel timeline">
        <h2>Batch Timeline</h2>
        <ol>
          {timeline}
        </ol>
      </aside>
    </section>
  </div>
</body>
</html>
"""


def render_site_card(site: dict[str, Any]) -> str:
    last_event = site.get("last_event") or {}
    last_url = html.escape(str(last_event.get("url", "n/a")))
    last_saved = html.escape(str(last_event.get("saved_path", "n/a")))
    status = site["status"]
    pages_value = site["pages_count"] if site["pages_count"] is not None else site["ok_count"]
    assets_value = site["assets_count"] if site["assets_count"] is not None else "n/a"
    total_value = site["total_count"] if site["total_count"] is not None else site["events_total"]
    return f"""
<article class="panel site-card">
  <div class="site-top">
    <div>
      <h3 class="site-name">{site["position"]}. {html.escape(site["id"])}</h3>
      <p class="site-sub">Dernier event: {html.escape(fmt_time(last_event.get("fetched_at") or last_event.get("timestamp")))}</p>
    </div>
    <span class="badge {html.escape(status)}">{html.escape(status)}</span>
  </div>
  <div class="stats">
    <div class="stat"><span class="small">Pages</span><span class="big">{pages_value}</span></div>
    <div class="stat"><span class="small">Assets</span><span class="big">{assets_value}</span></div>
    <div class="stat"><span class="small">Events</span><span class="big">{total_value}</span></div>
    <div class="stat"><span class="small">Saved</span><span class="big">{site["saved_files"]}</span></div>
  </div>
  <div class="meta">
    <span><strong>OK</strong> {site["ok_count"]}</span>
    <span><strong>Errors</strong> {site["error_count"]}</span>
    <span><strong>Skipped</strong> {site["skipped_count"]}</span>
    <span><strong>Disk</strong> {fmt_bytes(site["saved_bytes"])}</span>
  </div>
  <div class="meta">
    <span><strong>Last URL</strong> <code>{last_url}</code></span>
  </div>
  <div class="meta">
    <span><strong>Last file</strong> <code>{last_saved}</code></span>
  </div>
  <div class="links">
    <a href="{html.escape(site["summary_path"])}">summary.json</a>
    <a href="{html.escape(site["fetch_log_path"])}">fetch_log.jsonl</a>
    <a href="{html.escape(site["mirror_path"])}">mirror/</a>
  </div>
</article>
"""


def render_event(event: dict[str, str]) -> str:
    when = html.escape(fmt_time(event["timestamp"]))
    action = html.escape(event["action"])
    site = html.escape(event["site"])
    return f"<li><strong>{action}</strong> <code>{site}</code><br>{when}</li>"


if __name__ == "__main__":
    raise SystemExit(main())
