# ResumeForge Python Backend

A lightweight FastAPI server that handles PDF and LaTeX parsing for the
ResumeForge macOS app. The Swift app communicates with this server over HTTP
(`http://127.0.0.1:8765`) instead of embedding Python via PythonKit.

---

## Why a backend?

Using PythonKit to call `docling` inside the Swift process caused environment
fragility (Python dylib discovery, venv injection, etc.). A local HTTP server
is easier to install, debug, and upgrade independently of the app.

---

## Requirements

- **Python 3.10 or later**
- A virtual environment is strongly recommended

---

## Setup (one time)

```bash
cd backend/

# Create a virtual environment
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate

# Install core dependencies
pip install -r requirements.txt

# (Optional but recommended) Install docling for ML-powered PDF extraction
# docling provides much better results for complex resume layouts
pip install docling
```

---

## Running the server

```bash
cd backend/
source .venv/bin/activate
python app.py
```

The server starts on **http://127.0.0.1:8765** by default.
Override the port with the `RESUMEFORGE_PORT` environment variable:

```bash
RESUMEFORGE_PORT=9000 python app.py
```

---

## API

### `GET /health`

Returns the server status and which PDF parsers are available.

```json
{ "status": "ok", "parsers": ["docling", "pdfminer"] }
```

### `POST /parse-pdf`

Accepts a multipart/form-data request with a `file` field containing the PDF.

| Field           | Type    | Default | Description                                         |
|-----------------|---------|---------|-----------------------------------------------------|
| `file`          | File    | –       | The PDF file to parse                               |
| `prefer_docling`| Boolean | `true`  | Use docling first, fall back to pdfminer on failure |

**Response:**

```json
{
  "text": "..extracted markdown / plain text..",
  "parser": "docling",
  "char_count": 4321
}
```

### `POST /parse-latex`

Accepts a `source` form field containing LaTeX source code.

**Response:**

```json
{
  "text": "..plain text..",
  "char_count": 1234
}
```

---

## Running as a background service (launchd on macOS)

Create `~/Library/LaunchAgents/com.resumeforge.backend.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.resumeforge.backend</string>
  <key>ProgramArguments</key>
  <array>
    <string>/path/to/backend/.venv/bin/python</string>
    <string>/path/to/backend/app.py</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/resumeforge-backend.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/resumeforge-backend.log</string>
</dict>
</plist>
```

Then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.resumeforge.backend.plist
```

---

## Upgrading docling

```bash
cd backend/
source .venv/bin/activate
pip install --upgrade docling
```
