"""Uploaded-image ingest: re-encode to WebP, strip EXIF/GPS, cap dimensions.

Re-encoding (rather than storing the original) is what actually removes location
metadata and bounds storage/egress — the DEEP_SEARCH moderation-pipeline rule
("resize/re-encode to WebP/AVIF, strip EXIF, cap dimensions before storing").
"""

from __future__ import annotations

from io import BytesIO
from uuid import uuid4

from django.conf import settings
from django.core.files.base import ContentFile
from PIL import Image


class ImageRejected(ValueError):
    """Raised when an upload can't be decoded as an image."""


def process_upload(django_file) -> tuple[ContentFile, str, int, int]:
    """Return (content, filename, width, height) for a validated upload, or raise
    ImageRejected. The caller has already enforced the byte-size ceiling."""
    try:
        img = Image.open(django_file)
        img.load()
    except Exception as exc:  # Pillow raises a grab-bag of errors on bad input
        raise ImageRejected("not a decodable image") from exc

    has_alpha = img.mode in ("RGBA", "LA", "P")
    img = img.convert("RGBA" if has_alpha else "RGB")

    max_dim = settings.MNEMONIC_IMAGE_MAX_DIM
    img.thumbnail((max_dim, max_dim))  # only shrinks; preserves aspect ratio

    buf = BytesIO()
    # Writing a fresh WEBP drops every EXIF/GPS/ICC chunk from the source.
    img.save(buf, format="WEBP", quality=82, method=4)
    width, height = img.size
    return ContentFile(buf.getvalue()), f"{uuid4().hex}.webp", width, height
