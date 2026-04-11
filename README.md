# ResumeForge

ResumeForge is a native SwiftUI app that helps job seekers convert an existing resume into a role-specific application package.

## What The App Is For

Use ResumeForge when you want to:
- Import your current resume quickly (PDF or LaTeX).
- Convert resume content into structured profile data.
- Save target job descriptions you are applying to.
- Get multi-model AI recommendations to tailor your resume for each role.

## What The App Will Do (Product Goal)

ResumeForge is designed to provide an end-to-end application workflow:
1. Import and parse resume content.
2. Build and maintain a clean profile database.
3. Analyze fit against a job description.
4. Generate and refine tailored resume + cover letter drafts.
5. Export polished output files.

All five steps above are implemented in the current build.

## Current Status

| Area | Status | Notes |
|---|---|---|
| App shell and navigation | Implemented | Dashboard, Create, Profile, Documents, Settings tabs |
| Resume import and parsing | Implemented | PDF/LaTeX import, drag-drop, review before save |
| PDF extraction backend | Implemented | Docling first, PDFKit fallback |
| Profile management | Implemented | Edit contact, summary, skills, experience, education |
| Job description management | Implemented | Save role, company, full JD text |
| Style reference analysis | Implemented | Analyze sample writing style and store traits |
| AI Council analysis | Implemented | Parallel provider analysis + synthesis + token/cost estimate |
| Settings and provider config | Implemented | Provider setup, Keychain API keys, local parsing toggle |
| Cover Letter generation | Implemented | AI-assisted draft generation, editing, and save |
| Resume Builder | Implemented | Tailored generation with format-aware output guidance |
| Export | Implemented | Export generated resumes to PDF, LaTeX, and DOCX |
| Documents tab | Implemented (basic) | Tab and screen are active; advanced document management is in progress |

## How It Works

### Core flow

1. Import a resume from the Create tab.
2. Extract text.
3. Parse into structured data.
4. Review and edit parsed data.
5. Save into SwiftData profile records.
6. Add a target job description.
7. Convene AI Council for tailoring recommendations.
8. Generate cover letter and tailored resume drafts.
9. Export final versions for sharing.

### Parsing behavior

- PDF path:
	- Tries local Docling backend first for richer extraction.
	- If Docling is unavailable, falls back to native PDFKit extraction.
- LaTeX path:
	- Uses local LaTeX text extraction pipeline.

### AI behavior

- Uses enabled providers from settings.
- Runs analysis in parallel streams.
- Synthesizes outputs into prioritized recommendations.
- If initial startup setup is completed with Ollama enabled, provider config is constrained to Ollama-only for local-first usage.

### Data and secrets

- User data is stored locally with SwiftData.
- API keys are stored in Keychain.

## Who Should Use It

- Students and early-career applicants applying to many roles.
- Experienced professionals tailoring one base resume to many jobs.
- Anyone who wants local-first profile management plus BYO AI provider setup.

## How To Run

### Prerequisites

- macOS 14+
- Xcode 16+
- Python 3 (recommended for best PDF extraction via Docling)

### Quick Start (Xcode)

```bash
cd /Users/umangdeval/Documents/Projects/ResumeMaker
python3 -m venv .venv
./.venv/bin/python -m pip install --upgrade pip docling-parse
open ResumeForge.xcodeproj
```

In Xcode:
1. Select scheme `ResumeForge`
2. Select destination `My Mac`
3. Run

### CLI Build/Test

```bash
xcodebuild build -scheme ResumeForge -destination 'platform=macOS'
xcodebuild test -scheme ResumeForge -destination 'platform=macOS'
xcodebuild clean -scheme ResumeForge
```

### Package A DMG For Testing

Use the included helper script:

```bash
./scripts/make-dmg.sh
```

DMG output:

```text
dist/ResumeForge-Test.dmg
```

Useful options:

```bash
./scripts/make-dmg.sh --skip-build
./scripts/make-dmg.sh --help
```

### Optional: Verify Docling Backend

```bash
./.venv/bin/python ResumeForge/Resources/Python/docling_backend.py health
```

Healthy output should include `"ok": true` and `"docling": true`.

## Troubleshooting

### `docling-parse` not detected

```bash
./.venv/bin/python -m pip install --upgrade pip docling-parse
./.venv/bin/python ResumeForge/Resources/Python/docling_backend.py health
```

Restart app after install.

### Force a specific Python interpreter

```bash
export RESUMEFORGE_PYTHON=/absolute/path/to/python3
```

## Acknowledgments

Special thanks to Docling for powering high-quality PDF extraction in the local parsing pipeline:
- https://github.com/docling-project/docling

## Implementation Reference (Code Sources)

- `ResumeForge/App/ContentView.swift`
- `ResumeForge/App/CreateWorkflowView.swift`
- `ResumeForge/App/ResumeForgeApp.swift`
- `ResumeForge/Features/ResumeParser/ResumeParserView.swift`
- `ResumeForge/Features/ResumeParser/ResumeParserViewModel.swift`
- `ResumeForge/Features/ResumeParser/Services/DoclingPDFExtractor.swift`
- `ResumeForge/Features/ResumeParser/Services/PDFTextExtractor.swift`
- `ResumeForge/Features/ResumeParser/Services/LaTeXTextExtractor.swift`
- `ResumeForge/Features/JobDescription/JobDescriptionView.swift`
- `ResumeForge/Features/Profile/ProfileView.swift`
- `ResumeForge/Features/AICouncil/AICouncilView.swift`
- `ResumeForge/Features/AICouncil/Services/CouncilOrchestrator.swift`
- `ResumeForge/Features/Settings/AIProviderSettingsView.swift`
- `ResumeForge/Features/Settings/AIProviderSettingsModels.swift`
- `ResumeForge/Core/Services/PythonEnvironmentService.swift`
- `ResumeForge/Core/Services/LLMService.swift`
- `ResumeForge/Features/ResumeBuilder/ResumeBuilderPlaceholder.swift`
- `ResumeForge/Features/CoverLetter/CoverLetterPlaceholder.swift`
- `ResumeForge/Features/Export/ExportPlaceholder.swift`
- `project.yml`
