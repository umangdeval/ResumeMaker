# ResumeForge

ResumeForge is a SwiftUI macOS app for parsing resumes, tailoring content with multiple AI providers, and exporting polished outputs.

## Requirements

- macOS 14+
- Xcode 16+
- Python 3 (for Docling PDF parsing)

## Quick Start

1. Open Terminal in the project root.
2. Create and prepare the local Python environment:

```bash
python3 -m venv .venv
./.venv/bin/python -m pip install --upgrade pip
./.venv/bin/python -m pip install docling-parse
```

3. (Optional) Verify Docling backend health:

```bash
./.venv/bin/python ResumeForge/Resources/Python/docling_backend.py health
```

Expected output includes:

```json
{"ok": true, "docling": true, ...}
```

4. Open the app project:

```bash
open ResumeForge.xcodeproj
```

5. In Xcode:
- Select scheme: `ResumeForge`
- Destination: `My Mac`
- Press Run

## Run From Command Line

Build:

```bash
xcodebuild build -scheme ResumeForge -destination 'platform=macOS'
```

Test:

```bash
xcodebuild test -scheme ResumeForge -destination 'platform=macOS'
```

Clean:

```bash
xcodebuild clean -scheme ResumeForge
```

## How PDF Parsing Works

- ResumeForge first tries the local Python Docling backend for richer PDF extraction.
- If Docling is unavailable, the app falls back to native PDF extraction.

## Troubleshooting

### `pip` command not found

Use the venv-scoped pip instead of global pip:

```bash
./.venv/bin/python -m pip --version
```

### Docling not detected in app Settings

Run:

```bash
./.venv/bin/python -m pip install --upgrade docling-parse
./.venv/bin/python ResumeForge/Resources/Python/docling_backend.py health
```

Then restart the app.

### Wrong Python interpreter selected

The app prefers the local project interpreter at:

- `./.venv/bin/python3`

You can also override explicitly by setting:

- `RESUMEFORGE_PYTHON=/absolute/path/to/python3`

## Project Layout

```text
ResumeForge/
  App/
  Core/
  Features/
  Resources/
    Python/
Tests live under: ResumeForge/Tests/
```
