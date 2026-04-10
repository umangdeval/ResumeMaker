#!/usr/bin/env python3
"""
Downloads docling AI models into the project's Models/ directory.
Run once after cloning: python3 download_models.py
"""
import os
from pathlib import Path

VENV_PYTHON = os.path.expanduser("~/.resumeforge-venv/bin/python3")
MODELS_DIR = Path(__file__).parent / "Models"

def main():
    MODELS_DIR.mkdir(exist_ok=True)
    print(f"Downloading models to {MODELS_DIR} ...")

    from docling.models.stages.layout.layout_model import LayoutModel
    from docling.models.stages.table_structure.table_structure_model import TableStructureModel

    LayoutModel.download_models(local_dir=MODELS_DIR, progress=True)
    TableStructureModel.download_models(local_dir=MODELS_DIR, progress=True)

    print("Done! Models saved to", MODELS_DIR)

if __name__ == "__main__":
    main()
