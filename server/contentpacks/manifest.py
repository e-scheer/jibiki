"""Validation for the public content-pack manifest contract."""

from __future__ import annotations

from pathlib import PurePath

MANIFEST_SCHEMA = "jibiki-packs/3"


class InvalidManifest(ValueError):
    """Raised when a manifest cannot safely describe downloadable packs."""


def validate_manifest(value: object) -> dict:
    if not isinstance(value, dict) or value.get("schema") != MANIFEST_SCHEMA:
        raise InvalidManifest(f"expected manifest schema {MANIFEST_SCHEMA}")
    packs = value.get("packs")
    if not isinstance(packs, list):
        raise InvalidManifest("packs must be a list")

    ids: set[str] = set()
    files: set[str] = set()
    for pack in packs:
        if not isinstance(pack, dict):
            raise InvalidManifest("each pack must be an object")
        pack_id = pack.get("id")
        filename = pack.get("file")
        if not isinstance(pack_id, str) or not pack_id:
            raise InvalidManifest("each pack needs a non-empty id")
        if not isinstance(filename, str) or not filename.endswith(".db.gz"):
            raise InvalidManifest(f"pack {pack_id} has an invalid file")
        if PurePath(filename).name != filename or "\\" in filename:
            raise InvalidManifest(f"pack {pack_id} file must be a basename")
        if pack_id in ids:
            raise InvalidManifest(f"duplicate pack id {pack_id}")
        if filename in files:
            raise InvalidManifest(f"duplicate pack file {filename}")
        ids.add(pack_id)
        files.add(filename)

    for pack in packs:
        for requirement in pack.get("requires", []):
            if not isinstance(requirement, dict) or requirement.get("id") not in ids:
                raise InvalidManifest(f"pack {pack['id']} has an unknown dependency")
    return value
