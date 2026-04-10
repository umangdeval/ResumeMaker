"""
Legacy helper originally used by DoclingPDFExtractor via PythonKit.

PythonKit has been removed from the project. PDF parsing is now handled
by the standalone Python backend (backend/app.py). This file is kept for
reference only and is no longer imported at runtime.
"""

def create_converter(models_path: str):
    from docling.document_converter import DocumentConverter, PdfFormatOption
    from docling.datamodel.pipeline_options import PdfPipelineOptions
    from docling.datamodel.base_models import InputFormat

    opts = PdfPipelineOptions()
    opts.artifacts_path = models_path

    return DocumentConverter(
        format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=opts)}
    )


def convert_to_markdown(converter, pdf_path: str) -> str:
    result = converter.convert(pdf_path)
    return result.document.export_to_markdown()
