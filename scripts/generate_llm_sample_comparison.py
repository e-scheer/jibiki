from __future__ import annotations

import html
import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROTO_DIR = ROOT / "var" / "llm_prototype"
RAW_PATH = PROTO_DIR / "raw_html_sample.json"
FINAL_PATH = PROTO_DIR / "english_sample_candidate.json"
OUT_JSON_PATH = PROTO_DIR / "comparison_dataset.json"
OUT_HTML_PATH = PROTO_DIR / "comparison_report.html"

NOISE_PATTERNS = [
    "Add to ▼",
    "View Sentence Details",
    "Start Practice",
    "Sign In",
    "Comments",
    "Login",
    "Register here",
]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def clean_text(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def flatten_strings(value) -> list[str]:
    out: list[str] = []
    if isinstance(value, str):
        out.append(value)
    elif isinstance(value, list):
        for item in value:
            out.extend(flatten_strings(item))
    elif isinstance(value, dict):
        for item in value.values():
            out.extend(flatten_strings(item))
    return out


def empty_top_level_fields(item: dict) -> list[str]:
    empty = []
    for key, value in item.items():
        if key in {"category", "llm_pass_language", "source_site", "source_url"}:
            continue
        if value in (None, "", []):
            empty.append(key)
    return empty


def noise_hits(raw_item: dict, final_item: dict) -> list[str]:
    haystack = "\n".join(flatten_strings(raw_item.get("focus_blocks", {})) + flatten_strings(final_item))
    hits = [pattern for pattern in NOISE_PATTERNS if pattern in haystack]
    return sorted(set(hits))


def suspicious_hits(final_item: dict) -> list[str]:
    hits = []
    final_blob = "\n".join(flatten_strings(final_item))
    if re.search(r"\bPractice\b", final_blob):
        hits.append("Practice bleed")
    if re.search(r"View Sentence Details", final_blob):
        hits.append("Navigation bleed")
    if re.search(r"Add to ▼", final_blob):
        hits.append("Action bleed")
    return hits


def grade_item(raw_item: dict, final_item: dict) -> tuple[str, int]:
    missing = empty_top_level_fields(final_item)
    noise = noise_hits(raw_item, final_item)
    suspicious = suspicious_hits(final_item)
    score = 100
    score -= 7 * len(missing)
    score -= 4 * len(noise)
    score -= 8 * len(suspicious)
    score = max(score, 0)
    if score >= 88:
        grade = "strong"
    elif score >= 72:
        grade = "usable"
    else:
        grade = "review"
    return grade, score


def summarize_raw(raw_item: dict) -> dict:
    return {
        "html_title": raw_item.get("html_title"),
        "meta_description": raw_item.get("meta_description"),
        "h1": raw_item.get("h1"),
        "headings": raw_item.get("headings", []),
        "focus_blocks": raw_item.get("focus_blocks", {}),
        "body_preview": raw_item.get("body_preview"),
    }


def build_dataset() -> dict:
    raw = load_json(RAW_PATH)
    final = load_json(FINAL_PATH)
    final_by_url = {item["source_url"]: item for item in final["items"]}
    items = []
    for raw_item in raw["items"]:
        final_item = final_by_url.get(raw_item["url"])
        if final_item is None:
            continue
        grade, score = grade_item(raw_item, final_item)
        item = {
            "category": raw_item["category"],
            "source_site": raw_item["source_site"],
            "url": raw_item["url"],
            "saved_path": raw_item["saved_path"],
            "grade": grade,
            "score": score,
            "noise_hits": noise_hits(raw_item, final_item),
            "suspicious_hits": suspicious_hits(final_item),
            "empty_final_fields": empty_top_level_fields(final_item),
            "raw_summary": summarize_raw(raw_item),
            "final_candidate": final_item,
        }
        items.append(item)

    counts = Counter(item["category"] for item in items)
    grades = Counter(item["grade"] for item in items)
    sites = Counter(item["source_site"] for item in items)
    return {
        "summary": {
            "total": len(items),
            "by_category": dict(counts),
            "by_grade": dict(grades),
            "by_site": dict(sites),
        },
        "items": items,
    }


def pretty_json(value) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2)


def render_badges(item: dict) -> str:
    bits = [
        f'<span class="badge grade {item["grade"]}">{html.escape(item["grade"])} · {item["score"]}</span>',
        f'<span class="badge">{html.escape(item["category"])}</span>',
        f'<span class="badge">{html.escape(item["source_site"])}</span>',
    ]
    for key in item["noise_hits"]:
        bits.append(f'<span class="badge warn">{html.escape(key)}</span>')
    for key in item["suspicious_hits"]:
        bits.append(f'<span class="badge danger">{html.escape(key)}</span>')
    return "".join(bits)


def render_notes(item: dict) -> str:
    notes = []
    if item["empty_final_fields"]:
        notes.append(f'Empty final fields: {", ".join(item["empty_final_fields"])}')
    if item["noise_hits"]:
        notes.append(f'Noise still visible in raw/final chain: {", ".join(item["noise_hits"])}')
    if item["suspicious_hits"]:
        notes.append(f'Suspicious final content: {", ".join(item["suspicious_hits"])}')
    if not notes:
        notes.append("No obvious issue from the simple heuristic pass.")
    return "".join(f"<li>{html.escape(note)}</li>" for note in notes)


def render_item(item: dict, index: int) -> str:
    raw_summary = item["raw_summary"]
    final_candidate = item["final_candidate"]
    heading_text = raw_summary.get("h1") or raw_summary.get("html_title") or item["url"]
    return f"""
    <article class="item" data-category="{html.escape(item['category'])}" data-site="{html.escape(item['source_site'])}" data-grade="{html.escape(item['grade'])}">
      <header class="item-header">
        <div>
          <div class="eyebrow">Item {index + 1}</div>
          <h2>{html.escape(heading_text)}</h2>
          <div class="path"><a href="{html.escape(item['url'])}" target="_blank" rel="noreferrer">{html.escape(item['url'])}</a></div>
          <div class="path">{html.escape(item['saved_path'])}</div>
        </div>
        <div class="badges">{render_badges(item)}</div>
      </header>
      <section class="notes">
        <h3>Quick Read</h3>
        <ul>{render_notes(item)}</ul>
      </section>
      <div class="columns">
        <section class="panel">
          <h3>Raw Isolated HTML Packet</h3>
          <details open>
            <summary>Readable summary</summary>
            <div class="subpanel">
              <p><strong>Title:</strong> {html.escape(str(raw_summary.get('html_title') or ''))}</p>
              <p><strong>Meta:</strong> {html.escape(str(raw_summary.get('meta_description') or ''))}</p>
              <p><strong>H1:</strong> {html.escape(str(raw_summary.get('h1') or ''))}</p>
              <p><strong>Headings:</strong> {html.escape(" | ".join(raw_summary.get('headings', [])))}</p>
              <p><strong>Body preview:</strong> {html.escape(str(raw_summary.get('body_preview') or ''))}</p>
            </div>
          </details>
          <details open>
            <summary>Focus blocks</summary>
            <pre>{html.escape(pretty_json(raw_summary.get("focus_blocks", {})))}</pre>
          </details>
          <details>
            <summary>Full raw packet JSON</summary>
            <pre>{html.escape(pretty_json(item["raw_summary"]))}</pre>
          </details>
        </section>
        <section class="panel">
          <h3>Final English Candidate</h3>
          <details open>
            <summary>Full final JSON</summary>
            <pre>{html.escape(pretty_json(final_candidate))}</pre>
          </details>
        </section>
      </div>
    </article>
    """


def render_html(dataset: dict) -> str:
    summary = dataset["summary"]
    items = dataset["items"]
    summary_json = html.escape(json.dumps(summary, ensure_ascii=False, indent=2))
    items_html = "\n".join(render_item(item, idx) for idx, item in enumerate(items))
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LLM HTML Sample Comparison</title>
  <style>
    :root {{
      --bg: #f5efe6;
      --panel: #fffdf8;
      --ink: #1f1a17;
      --muted: #6f625a;
      --line: #ddcdbb;
      --accent: #1f6f5f;
      --warn: #a95f00;
      --danger: #9f2d2d;
      --strong: #2e7d32;
      --usable: #876100;
      --review: #8b1e3f;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: Georgia, "Times New Roman", serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, #fff6d6 0, transparent 28%),
        radial-gradient(circle at top right, #dceee7 0, transparent 24%),
        var(--bg);
    }}
    a {{ color: var(--accent); }}
    .wrap {{ max-width: 1500px; margin: 0 auto; padding: 24px; }}
    .hero {{
      background: linear-gradient(135deg, rgba(255,253,248,.96), rgba(244,236,224,.96));
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 22px;
      box-shadow: 0 14px 50px rgba(31, 26, 23, .08);
      margin-bottom: 20px;
    }}
    h1, h2, h3 {{ margin: 0; }}
    .subtitle {{ color: var(--muted); margin-top: 8px; max-width: 90ch; }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 12px;
      margin-top: 18px;
    }}
    .stat {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 14px;
      padding: 14px;
    }}
    .stat .label {{ color: var(--muted); font-size: 13px; }}
    .stat .value {{ font-size: 28px; margin-top: 8px; }}
    .controls {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 12px;
      margin: 18px 0;
    }}
    .control {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 12px;
    }}
    label {{ display: block; font-size: 13px; color: var(--muted); margin-bottom: 6px; }}
    select {{
      width: 100%;
      padding: 8px 10px;
      border-radius: 8px;
      border: 1px solid var(--line);
      background: white;
      font: inherit;
    }}
    .item {{
      background: rgba(255,253,248,.96);
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 18px;
      margin: 18px 0;
      box-shadow: 0 10px 35px rgba(31, 26, 23, .06);
    }}
    .item-header {{
      display: flex;
      gap: 16px;
      justify-content: space-between;
      align-items: start;
      margin-bottom: 14px;
    }}
    .eyebrow {{ font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }}
    .path {{ color: var(--muted); margin-top: 6px; word-break: break-all; font-size: 14px; }}
    .badges {{ display: flex; gap: 8px; flex-wrap: wrap; justify-content: end; }}
    .badge {{
      display: inline-flex;
      align-items: center;
      padding: 6px 10px;
      border-radius: 999px;
      background: #f1e6d9;
      border: 1px solid var(--line);
      font-size: 12px;
      white-space: nowrap;
    }}
    .badge.grade.strong {{ background: #dff3e3; color: var(--strong); border-color: #b6d8bc; }}
    .badge.grade.usable {{ background: #f8eed0; color: var(--usable); border-color: #dfcb8c; }}
    .badge.grade.review {{ background: #f6dde4; color: var(--review); border-color: #deb0bf; }}
    .badge.warn {{ background: #fff0da; color: var(--warn); border-color: #e6bf89; }}
    .badge.danger {{ background: #f7d9d9; color: var(--danger); border-color: #ddabab; }}
    .notes {{
      background: #faf4ec;
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 12px 14px;
      margin-bottom: 14px;
    }}
    .notes ul {{ margin: 8px 0 0 18px; }}
    .columns {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 16px;
    }}
    .panel {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 14px;
      padding: 14px;
      min-width: 0;
    }}
    .subpanel {{
      background: #fff;
      border: 1px solid #ece2d6;
      border-radius: 10px;
      padding: 12px;
      margin-top: 10px;
    }}
    details + details {{ margin-top: 12px; }}
    summary {{
      cursor: pointer;
      font-weight: 700;
      color: var(--accent);
    }}
    pre {{
      white-space: pre-wrap;
      word-break: break-word;
      overflow-wrap: anywhere;
      background: #fff;
      border: 1px solid #ece2d6;
      border-radius: 10px;
      padding: 12px;
      max-height: 640px;
      overflow: auto;
      margin-top: 10px;
      font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
      font-size: 12px;
      line-height: 1.45;
    }}
    .footer {{
      color: var(--muted);
      margin: 26px 0 10px;
    }}
    @media (max-width: 980px) {{
      .columns {{ grid-template-columns: 1fr; }}
      .item-header {{ flex-direction: column; }}
      .badges {{ justify-content: start; }}
    }}
  </style>
</head>
<body>
  <div class="wrap">
    <section class="hero">
      <h1>Raw HTML vs Final English Candidate</h1>
      <p class="subtitle">
        Local comparison artifact for the one-shot HTML-only prototype. The left panel shows what was isolated from stored HTML.
        The right panel shows the current end result candidate. Use filters to focus on `kana`, `kanji`, `word`, or weaker cases.
      </p>
      <div class="stats">
        <div class="stat"><div class="label">Total items</div><div class="value">{summary['total']}</div></div>
        <div class="stat"><div class="label">Strong</div><div class="value">{summary['by_grade'].get('strong', 0)}</div></div>
        <div class="stat"><div class="label">Usable</div><div class="value">{summary['by_grade'].get('usable', 0)}</div></div>
        <div class="stat"><div class="label">Review</div><div class="value">{summary['by_grade'].get('review', 0)}</div></div>
      </div>
      <details style="margin-top:14px;">
        <summary>Dataset summary JSON</summary>
        <pre>{summary_json}</pre>
      </details>
    </section>

    <section class="controls">
      <div class="control">
        <label for="category">Category</label>
        <select id="category">
          <option value="all">All</option>
          <option value="kana">kana</option>
          <option value="kanji">kanji</option>
          <option value="word">word</option>
        </select>
      </div>
      <div class="control">
        <label for="site">Site</label>
        <select id="site">
          <option value="all">All</option>
          <option value="kanjidraw">kanjidraw</option>
          <option value="wanikani">wanikani</option>
          <option value="tanoshii_japanese">tanoshii_japanese</option>
        </select>
      </div>
      <div class="control">
        <label for="grade">Quality bucket</label>
        <select id="grade">
          <option value="all">All</option>
          <option value="strong">strong</option>
          <option value="usable">usable</option>
          <option value="review">review</option>
        </select>
      </div>
    </section>

    <section id="items">
      {items_html}
    </section>

    <p class="footer">
      Heuristic grades are intentionally simple. They help you find likely weak items fast, not certify correctness.
    </p>
  </div>
  <script>
    const controls = {{
      category: document.getElementById("category"),
      site: document.getElementById("site"),
      grade: document.getElementById("grade"),
    }};
    const items = Array.from(document.querySelectorAll(".item"));
    function applyFilters() {{
      const category = controls.category.value;
      const site = controls.site.value;
      const grade = controls.grade.value;
      items.forEach((item) => {{
        const okCategory = category === "all" || item.dataset.category === category;
        const okSite = site === "all" || item.dataset.site === site;
        const okGrade = grade === "all" || item.dataset.grade === grade;
        item.style.display = okCategory && okSite && okGrade ? "" : "none";
      }});
    }}
    Object.values(controls).forEach((control) => control.addEventListener("change", applyFilters));
    applyFilters();
  </script>
</body>
</html>
"""


def main() -> None:
    dataset = build_dataset()
    OUT_JSON_PATH.write_text(json.dumps(dataset, ensure_ascii=False, indent=2), encoding="utf-8")
    OUT_HTML_PATH.write_text(render_html(dataset), encoding="utf-8")
    print(OUT_JSON_PATH)
    print(OUT_HTML_PATH)


if __name__ == "__main__":
    main()
