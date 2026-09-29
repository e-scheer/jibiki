"""Lossless source helpers shared by dictionary import commands."""

from __future__ import annotations

import gzip
import hashlib
import io
import json
import re
import xml.etree.ElementTree as ET
from contextlib import contextmanager
from pathlib import Path
from urllib.parse import urlparse

XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"
LANGUAGES = {
    "eng": "en",
    "fre": "fr",
    "fra": "fr",
    "ger": "de",
    "deu": "de",
    "dut": "nl",
    "nld": "nl",
    "rus": "ru",
    "spa": "es",
    "por": "pt",
    "hun": "hu",
    "slv": "sl",
    "swe": "sv",
    "ita": "it",
    "fin": "fi",
    "pol": "pl",
    "cze": "cs",
    "ces": "cs",
    "slo": "sk",
    "slk": "sk",
    "rum": "ro",
    "ron": "ro",
    "gre": "el",
    "ell": "el",
    "chi": "zh",
    "zho": "zh",
    "jpn": "ja",
    "kor": "ko",
    "vie": "vi",
    "tur": "tr",
    "tha": "th",
    "ukr": "uk",
    "ara": "ar",
}
ENTITY = re.compile(rb'<!ENTITY\s+([\w-]+)\s+"[^"]*">')


def language(code):
    return LANGUAGES.get(code.lower(), code.lower())


def source_provenance(path: Path, source: str) -> dict:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    provenance = {
        "source": source,
        "source_claim": source,
        "file": path.name,
        "sha256": digest.hexdigest(),
        "transformation": "deterministic_tanaka_import"
        if source == "tanaka"
        else "deterministic_xml_import",
        "authoring_method": "upstream_unspecified",
        "verified_download": False,
    }
    expected = {
        "jmdict": "JMdict.gz",
        "jmnedict": "JMnedict.xml.gz",
        "kanjidic2": "kanjidic2.xml.gz",
        "jmdict_examples": "JMdict_e_examp.gz",
        "tanaka": "examples.utf.gz",
    }.get(source)
    candidates = [path.with_name(path.name + ".download.json")]
    if path.suffix != ".gz":
        candidates.append(path.with_name(path.name + ".gz.download.json"))
    for sidecar in candidates:
        if not sidecar.is_file() or sidecar.stat().st_size > 65536:
            continue
        try:
            record = json.loads(sidecar.read_text(encoding="utf-8"))
            if not isinstance(record, dict):
                continue
            url = urlparse(record.get("url", ""))
        except (OSError, ValueError, TypeError):
            continue
        hash_key = "sha256" if path.suffix == ".gz" else "sha256_xml"
        if (
            expected
            and url.scheme in {"ftp", "https"}
            and url.hostname in {"ftp.edrdg.org", "www.edrdg.org", "edrdg.org"}
            and url.path == "/pub/Nihongo/" + expected
            and record.get(hash_key) == provenance["sha256"]
        ):
            provenance.update(
                verified_download=True,
                source_url=record["url"],
                fetched_at=record.get("fetched_at"),
                verification="local_download_sidecar_sha256",
            )
            break
    return provenance


def xml_metadata(element) -> dict:
    """Keep repeated tags, attributes and text, including unsupported source fields."""
    return {
        "tag": element.tag,
        "attributes": dict(element.attrib),
        "text": element.text or "",
        "children": [xml_metadata(child) for child in element],
    }


class _PrefixedStream:
    def __init__(self, prefix, stream):
        self.prefix = io.BytesIO(prefix)
        self.stream = stream

    def read(self, size=-1):
        first = self.prefix.read(size)
        if size < 0:
            return first + self.stream.read()
        return first + self.stream.read(size - len(first))


@contextmanager
def code_xml_stream(path: Path, root: str):
    """Rewrite only internal entity declarations so tag codes survive Expat.

    XMLParser.entity does not override declarations in the DTD. Replacing the
    declarations themselves preserves codes while retaining ordinary XML escaping.
    """
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rb") as stream:
        header = b""
        marker = re.compile(rb"<" + root.encode() + rb"(?:\s|>)")
        while not marker.search(header):
            chunk = stream.read(16384)
            if not chunk:
                raise ValueError(f"Missing {root} root element")
            header += chunk
            if len(header) > 1024 * 1024:
                raise ValueError("Dictionary XML header exceeds 1 MiB")
        header = ENTITY.sub(
            lambda match: b"<!ENTITY " + match[1] + b' "' + match[1] + b'">', header
        )
        yield _PrefixedStream(header, stream)


def entries(path: Path, root: str, tag: str):
    with code_xml_stream(path, root) as stream:
        parser = ET.iterparse(stream, events=("start", "end"))
        _, root_element = next(parser)
        for event, element in parser:
            if event == "end" and element.tag == tag:
                yield element
                element.clear()
                root_element.clear()
