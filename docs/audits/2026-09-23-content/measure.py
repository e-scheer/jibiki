"""Read-only evidence collection for the content architecture audit."""
import gzip
import csv
import hashlib
import json
import sqlite3
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.stdout.reconfigure(encoding="utf-8")


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def rows(db, sql):
    cur = db.execute(sql)
    keys = [c[0] for c in cur.description]
    return [dict(zip(keys, row)) for row in cur]


report = {"measured_on": "2026-09-23", "scope": "local release artifacts and source files; PostgreSQL unavailable (connection timeout)", "packs": {}}
manifest = read("var/packs/packs_manifest.json")
pack_entries = manifest["packs"]
report["manifest_schema"] = manifest.get("schema")
report["pack_hashes"] = {}
for pack in pack_entries:
    path = ROOT / "var/packs" / pack["file"]
    report["pack_hashes"][pack["id"]] = digest(path) == pack["sha256"]

kanji = {}
kana = {}
meaning_coverage = {}
published = set()
for pack in [read("app/assets/packs/base_manifest.json"), *pack_entries]:
    pid = pack["id"]
    if pid not in {"dict-base", "dict-core", "dict-locale-en", "dict-locale-fr", "mnemonics-en", "mnemonics-fr"}:
        continue
    path = ROOT / ("app/assets/packs" if pid == "dict-base" else "var/packs") / pack["file"]
    raw = gzip.decompress(path.read_bytes())
    db = sqlite3.connect(":memory:")
    db.deserialize(raw)
    db.execute("PRAGMA query_only=ON")
    item = {"version": pack["version"], "dataset_rev": pack["dataset_rev"], "compressed_bytes":path.stat().st_size,
            "db_sha256_matches": hashlib.sha256(raw).hexdigest() == pack["sha256_db"],
            "compressed_sha256_matches": digest(path) == pack["sha256"], "integrity": db.execute("PRAGMA quick_check").fetchone()[0]}
    del raw
    tables = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'gloss_fts%' AND name != 'meta'")]
    item["counts"] = {t: db.execute(f'SELECT count(*) FROM "{t}"').fetchone()[0] for t in tables}
    item["manifest_counts_match"] = all(item["counts"].get(k) == v for k, v in pack["counts"].items())
    if "glosses" in tables:
        item["gloss_coverage"] = rows(db, "SELECT language, count(*) AS glosses, count(DISTINCT word_id) AS words, count(DISTINCT sense_id) AS senses FROM glosses GROUP BY language")
    if "kanji_meanings" in tables:
        item["kanji_coverage"] = rows(db, "SELECT language, count(*) AS meanings, count(DISTINCT kanji) AS kanji FROM kanji_meanings GROUP BY language")
        if pid.startswith("dict-locale-"):
            for r in rows(db, "SELECT kanji,language,group_concat(text,'; ') AS text FROM kanji_meanings GROUP BY kanji,language"):
                meaning_coverage[(r["kanji"],r["language"])] = r["text"]
    if pid == "dict-base":
        item["sense_locale_sets"] = rows(db, "SELECT langs,count(*) AS senses FROM (SELECT sense_id,group_concat(DISTINCT language) langs FROM glosses GROUP BY sense_id) GROUP BY langs")
    if pid == "dict-core":
        kanji = {r["literal"]: r for r in rows(db, "SELECT literal,grade,jlpt,freq_rank,on_readings,kun_readings,components FROM kanji")}
        kana = {r["char"]:r for r in rows(db, 'SELECT char,romaji,script,kind,ord FROM kana ORDER BY script,ord')}
        item["words_with_jmdict_sequence"] = db.execute("SELECT count(*) FROM words WHERE seq IS NOT NULL").fetchone()[0]
        item["canonical_current_words"] = db.execute("SELECT count(*) FROM words WHERE seq IS NOT NULL AND canonical_word_id IS NULL AND COALESCE(json_extract(provenance,'$.source_status'),'') NOT IN ('upstream_not_in_snapshot','legacy_merged_entry')").fetchone()[0]
        item["kanji_grades"] = rows(db, "SELECT grade,count(*) AS n FROM kanji GROUP BY grade")
        item["kanji_jlpt"] = rows(db, "SELECT jlpt,count(*) AS n FROM kanji GROUP BY jlpt")
        item["words_with_frequency"] = db.execute("SELECT count(*) FROM words WHERE freq_rank IS NOT NULL").fetchone()[0]
    if "mnemonics" in tables:
        published.update(tuple(r) for r in db.execute("SELECT kind,character,language FROM mnemonics"))
        item["coverage"] = rows(db, "SELECT kind, language,count(*) AS n, sum(image IS NOT NULL) AS images FROM mnemonics GROUP BY kind,language")
        item["review_status"] = rows(db, "SELECT json_extract(provenance,'$.review_status') AS status,count(*) AS n FROM mnemonics GROUP BY status")
    report["packs"][pid] = item
    db.close()
    print("Measured", pid, flush=True)

seeds = {}
reading_mismatches = []
stories = set()
for path in sorted((ROOT / "server/content_sources/mnemonics").glob("*.json")):
    doc = json.loads(path.read_text(encoding="utf-8"))
    entries = doc.get("entries", doc.get("kanji", []))
    langs = doc["languages"]
    kind = "kana" if "kana_stories" in path.name else "kanji_reading" if "reading" in path.name else "kanji"
    for entry in entries:
        for lang in langs:
            stories.add((kind,entry.get("character",entry.get("literal")),lang))
    seeds[path.name] = {"targets": len(entries), "languages": langs, "stories": len(entries) * len(langs),
                       "entries_with_review": sum(bool(r.get("reviews")) for r in entries), "sha256": digest(path)}
    if "reading" in path.name:
        for entry in entries:
            canonical = kanji.get(entry["literal"])
            if not canonical or entry["reading"] not in json.loads(canonical["on_readings"]):
                reading_mismatches.append({"file":path.name, "literal":entry["literal"], "reading":entry["reading"],
                                           "canonical_on_readings":json.loads(canonical["on_readings"]) if canonical else None})
    if "meaning" in path.name:
        prefixes = Counter(r["en"].split(":")[0] for r in entries)
        seeds[path.name]["most_common_prefixes"] = prefixes.most_common(3)
report["seeds"] = seeds
report["reading_brief_canonical_mismatches"] = reading_mismatches

# Proposal only: existing N5/N4 mapping, extended with frequency from KANJIDIC.
baseline = sorted((r for r in kanji.values() if r["jlpt"] in (4,5)),key=lambda r:(-r["jlpt"],r["freq_rank"] or 999999,r["literal"]))
chosen = {r["literal"] for r in baseline}
for r in sorted(kanji.values(),key=lambda r:(r["freq_rank"] or 999999,r["literal"])):
    if len(baseline) >= 300:
        break
    if r["literal"] not in chosen:
        baseline.append(r)
        chosen.add(r["literal"])
with (OUT / "kanji-baseline-proposal.csv").open("w",newline="",encoding="utf-8-sig") as stream:
    writer = csv.writer(stream)
    writer.writerow(["position","kanji","selection_reason","jlpt_project_mapping","school_grade","frequency_rank_kanjidic","english_meanings","components_krad"])
    for position,r in enumerate(baseline,1):
        writer.writerow([position,r["literal"],"project_n5_n4" if r["jlpt"] in (4,5) else "frequency_extension",r["jlpt"],r["grade"],r["freq_rank"],meaning_coverage.get((r["literal"],"en"),""),r["components"]])
with (OUT / "baseline-gaps.csv").open("w",newline="",encoding="utf-8-sig") as stream:
    writer = csv.writer(stream)
    writer.writerow(["target_type","target","language","category","definition_present","story_candidate","story_in_release_pack","image_in_release_pack","recorded_review","next_work"])
    for r in kana.values():
        for lang in ("en","fr"):
            key=("kana",r["char"],lang)
            writer.writerow(["kana",r["char"],lang,r["kind"],"n/a",key in stories,key in published,False,False,"review_anchor_and_visual_brief" if key in stories else "design_derivation_rule_and_visual_support"])
    for r in baseline:
        for lang in ("en","fr"):
            key=("kanji",r["literal"],lang)
            writer.writerow(["kanji",r["literal"],lang,"meaning",(r["literal"],lang) in meaning_coverage,key in stories,key in published,False,False,"review_components_meaning_and_visual_brief"])
report["baseline_proposal"]={"kanji":len(baseline),"project_n5_n4":sum(r["jlpt"] in (4,5) for r in baseline),"frequency_extension":sum(r["jlpt"] not in (4,5) for r in baseline),"gap_rows":2*(len(kana)+len(baseline)),"status":"proposal_for_discussion_not_published"}

source_report = read("var/audit/source-corpus-after/report.json")
db = sqlite3.connect((ROOT / "var/audit/source-corpus-after/corpus.sqlite").as_uri() + "?mode=ro", uri=True)
report["corpus"] = {"records_recounted":db.execute("SELECT count(*) FROM records").fetchone()[0],
                    "historical_report_date":source_report["generated_at"],
                    "historical_sites":source_report["sites"]}
db.close()
report["source_file_sizes_match_catalogue"] = {}
for site, data in source_report["sites"].items():
    path = ROOT / "var/audit/site_extract_20260909" / site / "pages.jsonl"
    report["source_file_sizes_match_catalogue"][site] = path.stat().st_size == data["bytes"]
report["source_conflicts_recorded_20260909"] = source_report["disagreements"]
report["samples"] = {}
for folder in (ROOT / "misc/mnemonic-samples").iterdir():
    if folder.is_dir():
        files = [p for p in folder.rglob("*") if p.is_file()]
        report["samples"][folder.name] = {"files":len(files),"extensions":dict(Counter(p.suffix for p in files)),"bytes":sum(p.stat().st_size for p in files)}
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "measurements.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"packs":len(report["packs"]),"hashes_ok":all(report["pack_hashes"].values()),
                  "reading_mismatches":len(reading_mismatches),"output":str(OUT / 'measurements.json')},ensure_ascii=False))
