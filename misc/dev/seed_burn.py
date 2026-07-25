"""Dev tool: backdate qualified study days in a local jibiki user.db so burn
milestones fire without waiting real days (docs/REWARDS.md).

Typical loop on Windows desktop:
  1. cd app && flutter run -d windows
  2. in the app: continue as guest, add a few cards, finish one review
  3. close the app (releases the sqlite write lock cleanly)
  4. python misc/dev/seed_burn.py --days 6
  5. relaunch: burn = 7, milestones 3 and 7 grant two boosters

Seeded reviews are tagged (client_review_id prefix 'seed-burn-') and inserted
as already-synced so they never upload to an account by themselves. Use
--reset to remove them and wipe grants + collection for a fresh run.
"""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import os
import sqlite3
import sys
import uuid

SEED_PREFIX = "seed-burn-"


def discover_dbs() -> list[str]:
    patterns = []
    appdata = os.environ.get("APPDATA")
    if appdata:
        patterns += [
            os.path.join(appdata, "*", "jibiki", "user.db"),
            os.path.join(appdata, "jibiki", "user.db"),
        ]
    home = os.path.expanduser("~")
    patterns += [
        # macOS desktop / iOS simulator-ish locations, for completeness.
        os.path.join(home, "Library", "Application Support", "*", "user.db"),
    ]
    found: list[str] = []
    for pattern in patterns:
        found += glob.glob(pattern)
    return sorted(set(found), key=os.path.getmtime, reverse=True)


def qualified_days(conn: sqlite3.Connection) -> list[str]:
    rows = conn.execute(
        "SELECT DISTINCT date(reviewed_at / 1000, 'unixepoch') AS day "
        "FROM review_log ORDER BY day DESC"
    ).fetchall()
    return [row[0] for row in rows]


def seed(conn: sqlite3.Connection, days: int, include_today: bool) -> int:
    inserted = 0
    start = 0 if include_today else 1
    today = dt.date.today()
    for offset in range(start, start + days):
        day = today - dt.timedelta(days=offset)
        # Local noon, expressed in UTC ms like the app writes reviewed_at.
        noon = dt.datetime(day.year, day.month, day.day, 12).astimezone(dt.timezone.utc)
        conn.execute(
            "INSERT INTO review_log (client_review_id, item_type, item_ref, rating, "
            "state_before, duration_ms, reviewed_at, synced) VALUES (?, 'kana', "
            "'あ', 3, 0, 1500, ?, 1)",
            (f"{SEED_PREFIX}{uuid.uuid4()}", int(noon.timestamp() * 1000)),
        )
        inserted += 1
    conn.commit()
    return inserted


def reset(conn: sqlite3.Connection) -> None:
    removed = conn.execute(
        "DELETE FROM review_log WHERE client_review_id LIKE ?", (f"{SEED_PREFIX}%",)
    ).rowcount
    grants = conn.execute("DELETE FROM booster_grants").rowcount
    cards = conn.execute("DELETE FROM collection_cards").rowcount
    conn.commit()
    print(f"removed {removed} seeded reviews, {grants} grants, {cards} collection rows")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", help="path to user.db (default: auto-discover)")
    parser.add_argument(
        "--days", type=int, default=6, help="qualified days to backdate (default 6)"
    )
    parser.add_argument(
        "--include-today",
        action="store_true",
        help="also mark today as studied (default: leave today for a real review)",
    )
    parser.add_argument(
        "--reset", action="store_true", help="remove seeded reviews, grants and collection"
    )
    parser.add_argument("--list", action="store_true", help="only show current state")
    args = parser.parse_args()

    db_path = args.db
    if not db_path:
        candidates = discover_dbs()
        if not candidates:
            print("no user.db found; pass --db <path> (run the app once first)")
            return 1
        db_path = candidates[0]
        if len(candidates) > 1:
            print("multiple databases found, using the most recent:")
            for candidate in candidates:
                print(f"  {'->' if candidate == db_path else '  '} {candidate}")
    print(f"db: {db_path}")

    conn = sqlite3.connect(db_path)
    try:
        tables = {
            row[0]
            for row in conn.execute("SELECT name FROM sqlite_master WHERE type = 'table'")
        }
        if "review_log" not in tables or "booster_grants" not in tables:
            print("this database has no rewards schema yet; launch the app once first")
            return 1

        if args.reset:
            reset(conn)
        elif not args.list:
            inserted = seed(conn, args.days, args.include_today)
            print(f"seeded {inserted} qualified days")

        days = qualified_days(conn)
        grants = conn.execute(
            "SELECT grant_id, status FROM booster_grants ORDER BY granted_at"
        ).fetchall()
        collection = conn.execute("SELECT count(*), COALESCE(SUM(count), 0) FROM collection_cards").fetchone()
        print(f"qualified days (UTC view): {len(days)} - latest: {days[:8]}")
        print(f"grants: {[f'{g[0]} [{g[1]}]' for g in grants] or 'none yet (open the app)'}")
        print(f"collection: {collection[0]} distinct cards, {collection[1]} total copies")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
