"""
ResumeForge Python Backend
--------------------------
FastAPI server that handles PDF and LaTeX parsing for the ResumeForge macOS app.
The Swift app communicates with this server via HTTP instead of embedding Python
via PythonKit, which solves environment and installation reliability issues.

Endpoints:
  GET  /health       – liveness check, returns status + available parsers
  POST /parse-pdf    – accepts a PDF file, returns extracted markdown text
  POST /parse-latex  – accepts LaTeX source text, returns cleaned plain text
"""

from __future__ import annotations

import io
import logging
import os
import re
import sys
from typing import Annotated

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("resumeforge")

# ---------------------------------------------------------------------------
# Optional heavy dependencies – imported lazily so the server starts even if
# only the lightweight fallback (pdfminer) is available.
# ---------------------------------------------------------------------------

_docling_available = False
_pdfminer_available = False

try:
    from docling.datamodel.base_models import InputFormat
    from docling.datamodel.pipeline_options import PdfPipelineOptions
    from docling.document_converter import DocumentConverter, PdfFormatOption

    _docling_available = True
    log.info("docling is available – will use ML-powered PDF extraction")
except ImportError:
    log.info("docling not installed – falling back to pdfminer")

try:
    from pdfminer.high_level import extract_text as pdfminer_extract

    _pdfminer_available = True
    log.info("pdfminer.six is available")
except ImportError:
    log.warning("pdfminer.six not installed – PDF fallback unavailable")

# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------

app = FastAPI(
    title="ResumeForge Backend",
    description="PDF / LaTeX parsing service for the ResumeForge macOS app.",
    version="1.0.0",
)

# Allow requests from the loopback address only (the Swift app calls localhost).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost", "http://127.0.0.1"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Reuse a single docling converter across requests (expensive to initialise).
_converter: "DocumentConverter | None" = None


def _get_converter() -> "DocumentConverter":
    global _converter
    if _converter is None:
        opts = PdfPipelineOptions()
        # Use local models directory if it exists (pre-downloaded for offline use).
        models_dir = os.path.join(os.path.dirname(__file__), "..", "Models")
        if os.path.isdir(models_dir):
            opts.artifacts_path = os.path.abspath(models_dir)
        _converter = DocumentConverter(
            format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=opts)}
        )
    return _converter


def _extract_pdf_docling(data: bytes) -> str:
    """Convert PDF bytes → Markdown using docling."""
    import tempfile

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
        tmp.write(data)
        tmp_path = tmp.name
    try:
        converter = _get_converter()
        result = converter.convert(tmp_path)
        return result.document.export_to_markdown()
    finally:
        os.unlink(tmp_path)


def _extract_pdf_pdfminer(data: bytes) -> str:
    """Extract plain text from PDF bytes using pdfminer.six."""
    return pdfminer_extract(io.BytesIO(data)) or ""


def _clean_latex(source: str) -> str:
    """
    Lightweight LaTeX → plain-text conversion.
    Strips commands, environments, and common formatting macros.
    """
    # Remove comments
    text = re.sub(r"%.*", "", source)
    # Unwrap common text commands: \textbf{foo} → foo
    for cmd in ("textbf", "textit", "emph", "underline", "texttt",
                "textsc", "textrm", "textsf", "text"):
        text = re.sub(rf"\\{cmd}\{{([^}}]*)\}}", r"\1", text)
    # Remove \begin / \end blocks for document, resume, center, etc.
    text = re.sub(r"\\(begin|end)\{[^}]*\}", "", text)
    # Strip remaining backslash commands and their optional/mandatory args
    text = re.sub(r"\\[a-zA-Z]+\*?(\[[^\]]*\])?(\{[^}]*\})*", " ", text)
    # Remove leftover braces
    text = re.sub(r"[{}]", "", text)
    # Normalise whitespace
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/health")
async def health() -> JSONResponse:
    """Liveness check. Returns which parsers are available."""
    parsers: list[str] = []
    if _docling_available:
        parsers.append("docling")
    if _pdfminer_available:
        parsers.append("pdfminer")
    if not parsers:
        return JSONResponse(
            status_code=503,
            content={"status": "degraded", "parsers": parsers,
                     "message": "No PDF parser available. Install pdfminer.six or docling."},
        )
    return JSONResponse({"status": "ok", "parsers": parsers})


@app.post("/parse-pdf")
async def parse_pdf(
    file: Annotated[UploadFile, File(description="PDF file to parse")],
    prefer_docling: Annotated[bool, Form()] = True,
) -> JSONResponse:
    """
    Parse a PDF and return its text content.

    Tries docling first (ML-powered, layout-aware) when available and
    `prefer_docling` is true; falls back to pdfminer.six on failure or
    when docling is not installed.
    """
    if file.content_type not in ("application/pdf", "application/octet-stream"):
        raise HTTPException(status_code=415, detail="File must be a PDF.")

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file received.")

    log.info("parse-pdf  name=%s  size=%d bytes  prefer_docling=%s",
             file.filename, len(data), prefer_docling)

    text: str = ""
    parser_used: str = "none"
    error_detail: str = ""

    # --- Try docling ---
    if _docling_available and prefer_docling:
        try:
            text = _extract_pdf_docling(data)
            parser_used = "docling"
            log.info("docling extracted %d chars", len(text))
        except Exception as exc:  # noqa: BLE001
            log.warning("docling failed: %s – falling back to pdfminer", exc)
            error_detail = str(exc)

    # --- Fallback to pdfminer ---
    if not text and _pdfminer_available:
        try:
            text = _extract_pdf_pdfminer(data)
            parser_used = "pdfminer"
            log.info("pdfminer extracted %d chars", len(text))
        except Exception as exc:  # noqa: BLE001
            log.warning("pdfminer failed: %s", exc)
            error_detail = str(exc)

    if not text.strip():
        raise HTTPException(
            status_code=422,
            detail=f"Could not extract text from PDF. {error_detail}".strip(),
        )

    return JSONResponse({
        "text": text,
        "parser": parser_used,
        "char_count": len(text),
    })


@app.post("/parse-latex")
async def parse_latex(
    source: Annotated[str, Form(description="LaTeX source code")],
) -> JSONResponse:
    """
    Convert LaTeX source to plain text.
    Uses a lightweight built-in converter (no external dependencies).
    """
    if not source.strip():
        raise HTTPException(status_code=400, detail="Empty LaTeX source received.")

    log.info("parse-latex  input_len=%d chars", len(source))
    text = _clean_latex(source)

    if not text.strip():
        raise HTTPException(status_code=422, detail="LaTeX conversion produced no text.")

    return JSONResponse({"text": text, "char_count": len(text)})


# ---------------------------------------------------------------------------
# Entry-point (for `python app.py`)
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("RESUMEFORGE_PORT", "8765"))
    log.info("Starting ResumeForge backend on http://127.0.0.1:%d", port)
    uvicorn.run("app:app", host="127.0.0.1", port=port, reload=False)
