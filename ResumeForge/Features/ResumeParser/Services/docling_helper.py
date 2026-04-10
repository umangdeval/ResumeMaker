"""
Thin wrapper around docling so Swift/PythonKit only needs to make simple calls
with string arguments — no Python enum or dict construction on the Swift side.
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
