import importlib.util
import sqlite3
from pathlib import Path


def test_accent_export_uses_complete_okurigana_surface(tmp_path):
    spec = importlib.util.spec_from_file_location(
        "extract_kanjium_data", Path(__file__).parents[1] / "extract_kanjium_data.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    connection = sqlite3.connect(":memory:")
    connection.execute("create table edict(kanji,reading,okurigana,acc_pos)")
    connection.executemany(
        "insert into edict values (?,?,?,?)",
        [
            ("上", "あげる", "上げる", "0"),
            ("上", "あげる", "上げる", "0"),
            ("水", "みず", None, "0"),
            ("", "ありがとう", "", "2"),
        ],
    )
    output = tmp_path / "accents.txt"
    assert module.export_accents(connection, output) == 3
    assert output.read_text(encoding="utf-8").splitlines() == [
        "上げる\tあげる\t0",
        "水\tみず\t0",
        "ありがとう\tありがとう\t2",
    ]
