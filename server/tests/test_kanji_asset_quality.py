import xml.etree.ElementTree as ET

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError

from dictionary.models import Kanji

pytestmark = pytest.mark.django_db


def test_kanjivg_xml_paths_provenance_and_rollback(tmp_path):
    kanji = Kanji.objects.create(literal="水", stroke_count=4, provenance={"kept": True})
    path = tmp_path / "06c34.svg"
    path.write_text(
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 109 109'>"
        "<path d='M1 2 L3 4'/><path d='M5 6 L7 8'/></svg>",
        encoding="utf-8",
    )
    call_command("import_kanjivg", str(tmp_path))
    kanji.refresh_from_db()
    assert kanji.stroke_paths == ["M1 2 L3 4", "M5 6 L7 8"]
    assert kanji.stroke_count == 4  # Source stroke counts and diagrams stay distinct.
    assert kanji.provenance["kept"] is True
    assert len(kanji.provenance["kanjivg"]["sha256"]) == 64
    before = kanji.stroke_paths
    Kanji.objects.create(literal="日", stroke_count=4)
    (tmp_path / "065e5.svg").write_text("<svg><path", encoding="utf-8")
    path.write_text("<svg><path d='changed'/></svg>", encoding="utf-8")
    with pytest.raises(ET.ParseError):
        call_command("import_kanjivg", str(tmp_path))
    kanji.refresh_from_db()
    assert kanji.stroke_paths == before


def test_kradfile_preserves_other_sources_and_rejects_partial_import(tmp_path):
    kanji = Kanji.objects.create(literal="水", stroke_count=4, provenance={"kept": True})
    path = tmp_path / "components.txt"
    path.write_text("# source\n水 : 水\n", encoding="utf-8")
    call_command("import_kradfile", str(path))
    kanji.refresh_from_db()
    assert kanji.components == ["水"] and kanji.provenance["kept"] is True
    path.write_text("水 : 木\nmalformed\n", encoding="utf-8")
    with pytest.raises(CommandError):
        call_command("import_kradfile", str(path))
    kanji.refresh_from_db()
    assert kanji.components == ["水"]
