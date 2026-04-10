#!/usr/bin/env python3
"""Local Docling backend for ResumeForge.

Commands:
- health
- extract --pdf /absolute/path/to/file.pdf
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any


def _emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=True))


def _import_docling_parse() -> Any:
    try:
        from docling_parse.pdf_parser import DoclingPdfParser  # type: ignore

        return DoclingPdfParser
    except Exception as exc:  # pragma: no cover
        raise RuntimeError(str(exc)) from exc


def cmd_health() -> int:
    payload: dict[str, Any] = {
        "ok": False,
        "python": sys.version.split()[0],
        "docling": False,
    }

    try:
        _import_docling_parse()
        payload["ok"] = True
        payload["docling"] = True
        _emit(payload)
        return 0
    except Exception as exc:
        payload["error"] = str(exc)
        _emit(payload)
        return 2


def _extract_text(docling_parser_type: Any, pdf_path: str) -> str:
    parser = docling_parser_type()
    document = parser.load(pdf_path, lazy=False)

    total_pages = int(document.number_of_pages())
    if total_pages <= 0:
        raise RuntimeError("No pages were extracted")

    def _normalize_page(page_item: Any) -> Any:
        if hasattr(page_item, "iterate_cells"):
            return page_item
        if isinstance(page_item, tuple):
            for candidate in page_item:
                if hasattr(candidate, "iterate_cells"):
                    return candidate
        raise RuntimeError("Unexpected page shape returned by docling parser")

    def _page_cells(page: Any) -> list[Any]:
        unit_type = page.iterate_cells.__annotations__.get("unit_type")
        if unit_type is None:
            raise RuntimeError("Docling page API missing unit_type annotation")

        # Prefer lines for readable output; fall back to word/char for compatibility.
        unit_candidates = [
            getattr(unit_type, "LINE", None),
            getattr(unit_type, "WORD", None),
            getattr(unit_type, "CHAR", None),
        ]

        for candidate in unit_candidates:
            if candidate is None:
                continue
            try:
                cells = list(page.iterate_cells(candidate))
                if cells:
                    return cells
            except Exception:
                continue

        return []
    def _normalize_lines(raw_lines: list[str]) -> list[str]:
        cleaned: list[str] = []
        bullet_pending = False

        for raw in raw_lines:
            line = re.sub(r"\s+", " ", raw).strip()
            if not line:
                continue
            if re.fullmatch(r"[.\s]{2,}", line):
                continue

            if line in {"•", "-"}:
                bullet_pending = True
                continue

            if bullet_pending:
                cleaned.append(f"• {line}")
                bullet_pending = False
            else:
                cleaned.append(line)

        return cleaned

    raw_text_parts: list[str] = []
    for page_item in document.iterate_pages():
        page = _normalize_page(page_item)
        cells = _page_cells(page)
        if cells:
            for cell in cells:
                cell_text = str(getattr(cell, "text", "") or "").strip()
                if cell_text:
                    raw_text_parts.append(cell_text)

    text_parts = _normalize_lines(raw_text_parts)

    full_text = "\n".join(text_parts).strip()
    if not full_text:
        raise RuntimeError("Docling extracted no text")

    return full_text


def cmd_extract(pdf_path: str) -> int:
    try:
        docling_parser_type = _import_docling_parse()
        text = _extract_text(docling_parser_type, pdf_path)
        _emit({"ok": True, "text": text})
        return 0
    except Exception as exc:
        _emit({"ok": False, "error": str(exc)})
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="docling_backend")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("health")

    extract_parser = subparsers.add_parser("extract")
    extract_parser.add_argument("--pdf", required=True, help="Absolute path to PDF file")

    return parser


def main() -> int:
    args = build_parser().parse_args()

    if args.command == "health":
        return cmd_health()

    if args.command == "extract":
        return cmd_extract(args.pdf)

    _emit({"ok": False, "error": "Unsupported command"})
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
