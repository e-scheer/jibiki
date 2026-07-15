"""Extract harvested Yomitan/ZIP dictionaries and write a compact inventory.

By default this scans the harvested `jmdict_yomitan` and `jitendex` directories
and unpacks every `.zip` into a sibling folder under `extracted/`.
"""

from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path
from typing import Any


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--roots",
        nargs="*",
        default=[
            "var/source_harvest/upstreams/jmdict_yomitan",
            "var/source_harvest/upstreams/jitendex",
        ],
        help="Directories to scan for harvested zip archives.",
    )
    args = parser.parse_args()

    inventories: dict[str, Any] = {}
    for root_str in args.roots:
        root = Path(root_str)
        if not root.exists():
            continue
        inventories[str(root)] = extract_root(root)

    out_path = Path("var/source_harvest/yomitan_inventory.json")
    out_path.write_text(json.dumps(inventories, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out_path}")
    return 0


def extract_root(root: Path) -> dict[str, Any]:
    extracted_root = root / "extracted"
    extracted_root.mkdir(parents=True, exist_ok=True)
    result: dict[str, Any] = {"archives": []}
    for archive in sorted(root.glob("*.zip")):
        dest = extracted_root / archive.stem
        dest.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as zf:
            zf.extractall(dest)
            members = []
            for info in zf.infolist():
                members.append(
                    {
                        "name": info.filename,
                        "bytes": info.file_size,
                    }
                )
        result["archives"].append(
            {
                "archive": str(archive),
                "extracted_to": str(dest),
                "files": members,
            }
        )
    return result


if __name__ == "__main__":
    raise SystemExit(main())
