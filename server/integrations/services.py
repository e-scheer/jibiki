from __future__ import annotations

import base64
import hashlib
import json
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Iterable

from cryptography.fernet import Fernet, InvalidToken
from django.conf import settings
from django.utils import timezone

from dictionary.models import Kanji, Word
from srs.models import Card, ItemType
from srs.services import bulk_add

from .models import WaniKaniConnection

WANI_KANI_API = "https://api.wanikani.com/v2"
MASTERY_THRESHOLDS = {"guru": 5, "master": 7, "burned": 9}
THRESHOLD_NAMES = {value: key for key, value in MASTERY_THRESHOLDS.items()}


class WaniKaniError(RuntimeError):
    pass


def _cipher() -> Fernet:
    key = base64.urlsafe_b64encode(hashlib.sha256(settings.SECRET_KEY.encode()).digest())
    return Fernet(key)


def encrypt_token(token: str) -> str:
    return _cipher().encrypt(token.strip().encode()).decode()


def decrypt_token(connection: WaniKaniConnection) -> str:
    try:
        return _cipher().decrypt(connection.token_ciphertext.encode()).decode()
    except (InvalidToken, UnicodeDecodeError) as exc:
        raise WaniKaniError("The saved WaniKani token cannot be decrypted.") from exc


class WaniKaniClient:
    def __init__(self, token: str):
        self.token = token

    def get(self, path: str, query: dict[str, str] | None = None) -> dict:
        url = f"{WANI_KANI_API}{path}"
        if query:
            url = f"{url}?{urllib.parse.urlencode(query)}"
        request = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Wanikani-Revision": "20170710",
                "Accept": "application/json",
                "User-Agent": "jibiki/1.0",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 403):
                raise WaniKaniError("WaniKani rejected this API token.") from exc
            raise WaniKaniError(f"WaniKani returned HTTP {exc.code}.") from exc
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            raise WaniKaniError("WaniKani could not be reached right now.") from exc

    def collection(self, path: str, query: dict[str, str] | None = None) -> list[dict]:
        url_query = dict(query or {})
        rows: list[dict] = []
        while True:
            payload = self.get(path, url_query)
            rows.extend(payload.get("data", []))
            next_url = (payload.get("pages") or {}).get("next_url")
            if not next_url:
                return rows
            parsed = urllib.parse.urlparse(next_url)
            url_query = dict(urllib.parse.parse_qsl(parsed.query))
            path = parsed.path.removeprefix("/v2")


def _chunks(values: Iterable[int], size: int = 100) -> Iterable[list[int]]:
    chunk: list[int] = []
    for value in values:
        chunk.append(value)
        if len(chunk) == size:
            yield chunk
            chunk = []
    if chunk:
        yield chunk


def _existing_cards(user) -> set[tuple[str, str]]:
    cards = Card.objects.filter(user=user).select_related("word", "kanji", "kana")
    return {(card.item_type, card.item_ref) for card in cards}


def build_wanikani_preview(user, token: str, mastery_threshold: str = "guru") -> dict:
    if mastery_threshold not in MASTERY_THRESHOLDS:
        raise WaniKaniError("Choose Guru, Master, or Burned as the mastery threshold.")

    client = WaniKaniClient(token)
    user_data = client.get("/user").get("data") or {}
    assignments = client.collection(
        "/assignments",
        {"started": "true", "subject_types": "kanji,vocabulary"},
    )
    assignment_by_subject = {
        int(row["data"]["subject_id"]): row["data"]
        for row in assignments
        if row.get("data", {}).get("subject_id") is not None
    }
    subjects: list[dict] = []
    for ids in _chunks(assignment_by_subject):
        subjects.extend(client.collection("/subjects", {"ids": ",".join(map(str, ids))}))

    existing = _existing_cards(user)
    items: list[dict] = []
    ambiguous = 0
    ignored = 0
    seen: set[tuple[str, str]] = set()
    threshold = MASTERY_THRESHOLDS[mastery_threshold]

    for subject in subjects:
        data = subject.get("data") or {}
        characters = data.get("characters")
        kind = subject.get("object")
        assignment = assignment_by_subject.get(int(subject.get("id", 0)), {})
        if not characters or kind not in {"kanji", "vocabulary"}:
            ignored += 1
            continue
        if kind == "kanji":
            matches = list(Kanji.objects.filter(literal=characters).values_list("literal", flat=True))
            item_type = ItemType.KANJI
            refs = matches
        else:
            matches = list(
                Word.objects.filter(forms__text=characters)
                .distinct()
                .values_list("id", flat=True)
            )
            item_type = ItemType.WORD
            refs = [str(ref) for ref in matches]
        if not refs:
            ignored += 1
            continue
        if len(refs) > 1:
            ambiguous += 1
            continue
        ref = refs[0]
        key = (item_type, ref)
        if key in seen:
            continue
        seen.add(key)
        stage = int(assignment.get("srs_stage") or 0)
        items.append(
            {
                "item_type": item_type,
                "ref": ref,
                "known": stage >= threshold,
                "external_id": int(subject["id"]),
                "srs_stage": stage,
            }
        )

    new_items = [item for item in items if (item["item_type"], item["ref"]) not in existing]
    known = [item for item in new_items if item["known"]]
    learning = [item for item in new_items if not item["known"]]
    return {
        "provider": "wanikani",
        "username": (user_data.get("username") or ""),
        "threshold": mastery_threshold,
        "threshold_stage": threshold,
        "recognized": len(items),
        "ambiguous": ambiguous,
        "ignored": ignored,
        "new_cards": len(new_items),
        "known_cards": len(known),
        "learning_cards": len(learning),
        "estimated_new_reviews": len(learning),
        "items": items,
        "generated_at": timezone.now().isoformat(),
    }


def save_wanikani_preview(
    user, token: str, mastery_threshold: str = "guru"
) -> tuple[WaniKaniConnection, dict]:
    preview = build_wanikani_preview(user, token, mastery_threshold)
    connection, _ = WaniKaniConnection.objects.update_or_create(
        user=user,
        defaults={
            "token_ciphertext": encrypt_token(token),
            "username": preview["username"],
            "mastery_threshold": preview["threshold_stage"],
            "pending_preview": preview,
            "last_synced_at": timezone.now(),
            "last_error": "",
        },
    )
    return connection, preview


def refresh_wanikani_preview(connection: WaniKaniConnection) -> dict:
    threshold = THRESHOLD_NAMES.get(connection.mastery_threshold, "guru")
    try:
        _, preview = save_wanikani_preview(
            connection.user, decrypt_token(connection), threshold
        )
        return preview
    except WaniKaniError as exc:
        connection.last_error = str(exc)
        connection.save(update_fields=["last_error", "updated_at"])
        raise


def import_wanikani_preview(connection: WaniKaniConnection) -> dict:
    preview = connection.pending_preview or {}
    items = preview.get("items") or []
    if not items:
        return {"requested": 0, "resolved": 0, "created": 0, "known": 0, "learning": 0}
    known_items = [
        {"item_type": item["item_type"], "ref": item["ref"]}
        for item in items
        if item.get("known")
    ]
    learning_items = [
        {"item_type": item["item_type"], "ref": item["ref"]}
        for item in items
        if not item.get("known")
    ]
    known_summary = bulk_add(connection.user, known_items, known=True)
    learning_summary = bulk_add(connection.user, learning_items, known=False)
    connection.mark_imported()
    return {
        "requested": len(items),
        "resolved": known_summary["resolved"] + learning_summary["resolved"],
        "created": known_summary["created"] + learning_summary["created"],
        "known": known_summary["resolved"],
        "learning": learning_summary["resolved"],
    }
