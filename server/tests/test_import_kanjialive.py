import hashlib
import json

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError
from rest_framework.test import APIClient

from dictionary.models import Kanji, Radical, RadicalMeaning

pytestmark = pytest.mark.django_db


def fixture(tmp_path):
    normal = {
        "id": 12,
        "literal": "⺅",
        "stroke_count": 2,
        "reading_ja": "にんべん",
        "meaning": "person",
    }
    private = {
        "id": 5,
        "literal": "\ue731",
        "stroke_count": 1,
        "reading_ja": "のかんむり",
        "meaning": "diagonal sweeping stroke",
    }

    def relation(literal, catalogue, order):
        return {
            "literal": literal,
            "radical": {
                "id": order,
                "literal": catalogue["literal"],
                "name_ja": catalogue["reading_ja"],
                "stroke_count": catalogue["stroke_count"],
                "meaning": catalogue["meaning"],
                "catalog_entry": catalogue,
                "position_ja": "へん",
            },
        }

    document = {
        "schema": "jibiki-kanji-alive-open-data/1",
        "source": {"license": "CC BY 4.0"},
        "counts": {"radicals": 2, "kanji": 2},
        "radicals": [normal, private],
        "kanji": [relation("何", normal, 11), relation("一", private, None)],
    }
    path = tmp_path / "kanji_alive.json"
    path.write_text(json.dumps(document), encoding="utf8")
    manifest = tmp_path / "manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "sources": {
                    "kanjialive": {
                        "license": "CC BY 4.0",
                        "files": [
                            {
                                "path": str(path),
                                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                            }
                        ],
                    }
                }
            }
        ),
        encoding="utf8",
    )
    return path, manifest


def test_source_scoped_radicals_preserve_canonical_data_and_are_idempotent(tmp_path):
    kanji = Kanji.objects.create(
        literal="何",
        stroke_count=7,
        radical_number=9,
        components=["亻", "可"],
        on_readings=["カ"],
        metadata={"existing": True},
    )
    Kanji.objects.create(literal="一")
    radical = Radical.objects.create(literal="⺅", reading="existing", strokes=3)
    RadicalMeaning.objects.create(radical=radical, language="fr", text="personne")
    RadicalMeaning.objects.create(radical=radical, language="en", text="existing English")
    path, manifest = fixture(tmp_path)
    report = tmp_path / "report.json"
    call_command("import_kanjialive", path, manifest=manifest, report=report, dry_run=True)
    kanji.refresh_from_db()
    assert kanji.metadata == {"existing": True}
    call_command("import_kanjialive", path, manifest=manifest, report=report)
    kanji.refresh_from_db()
    radical.refresh_from_db()
    assert (kanji.stroke_count, kanji.radical_number, kanji.components, kanji.on_readings) == (
        7,
        9,
        ["亻", "可"],
        ["カ"],
    )
    assert kanji.metadata["existing"] is True
    assert kanji.metadata["kanjialive"]["radical"]["source_radical_catalogue_id"] == 12
    assert radical.reading == "existing" and radical.strokes == 3
    assert radical.meanings.get(language="en").text == "existing English"
    assert radical.meanings.get(language="fr").text == "personne"
    private = Kanji.objects.get(literal="一").metadata["kanjialive"]["radical"]
    assert private["glyph_available"] is False and private["literal"] == ""
    assert not Radical.objects.filter(literal="\ue731").exists()
    before = list(Kanji.objects.order_by("pk").values()), list(Radical.objects.values())
    call_command("import_kanjialive", path, manifest=manifest, report=report)
    assert before == (list(Kanji.objects.order_by("pk").values()), list(Radical.objects.values()))
    response = APIClient().get("/api/v1/dict/kanji", {"contains": "⺅"})
    assert response.status_code == 200
    payload = response.json()
    rows = payload["results"] if isinstance(payload, dict) else payload
    assert [row["literal"] for row in rows] == ["何"]


def test_new_standard_radical_gets_language_scoped_meaning_and_provenance(tmp_path):
    path, manifest = fixture(tmp_path)
    call_command("import_kanjialive", path, manifest=manifest, report=tmp_path / "report.json")
    radical = Radical.objects.get(literal="⺅")
    assert radical.reading == "にんべん" and radical.strokes == 2
    assert list(radical.meanings.values_list("language", "text")) == [("en", "person")]
    assert radical.provenance["field_sources"]["meaning_en"] == "kanjialive"


def test_source_checksum_mismatch_rejects_before_writing(tmp_path):
    path, manifest = fixture(tmp_path)
    path.write_text(path.read_text() + " ", encoding="utf8")
    with pytest.raises(CommandError, match="SHA-256"):
        call_command("import_kanjialive", path, manifest=manifest, report=tmp_path / "report.json")
    assert Radical.objects.count() == 0


def test_iteration_mark_placeholder_is_not_imported_as_a_radical(tmp_path):
    path, manifest = fixture(tmp_path)
    document = json.loads(path.read_text())
    document["radicals"].append(
        {"id": 322, "literal": "々", "stroke_count": None, "reading_ja": "n/a", "meaning": "n/a"}
    )
    document["counts"]["radicals"] += 1
    path.write_text(json.dumps(document), encoding="utf8")
    proof = json.loads(manifest.read_text())
    proof["sources"]["kanjialive"]["files"][0]["sha256"] = hashlib.sha256(
        path.read_bytes()
    ).hexdigest()
    manifest.write_text(json.dumps(proof), encoding="utf8")
    report = tmp_path / "report.json"
    call_command("import_kanjialive", path, manifest=manifest, report=report)
    assert not Radical.objects.filter(literal="々").exists()
    assert any(
        row["reason"] == "source_has_no_radical_definition_or_strokes"
        for row in json.loads(report.read_text(encoding="utf8"))["quarantine"]
    )
