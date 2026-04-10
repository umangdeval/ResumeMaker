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

Today, steps 1 through 3 are implemented, while resume builder / cover letter / export are still in progress.

## Current Status

| Area | Status | Notes |
|---|---|---|
| App shell and navigation | Implemented | Dashboard, Create, Profile, Documents, Settings tabs |
| Resume import and parsing | Implemented | PDF/LaTeX import, drag-drop, review before save |
| PDF extraction backend | Implemented | Docling first, PDFKit fallback |
| Profile management | Implemented | Edit contact, summary, skills, experience, education |
| Job description management | Implemented | Save role, company, full JD text |
| AI Council analysis | Implemented | Parallel provider analysis + synthesis + token/cost estimate |
| Settings and provider config | Implemented | Provider setup, Keychain API keys, local parsing toggle |
| Documents tab | Placeholder | UI present, feature not complete |
| Resume Builder | Placeholder | Not implemented yet |
| Cover Letter | Placeholder | Not implemented yet |
| Export | Placeholder | Not implemented yet |

## How It Works

### Core flow

1. Import a resume from the Create tab.
2. Extract text.
3. Parse into structured data.
4. Review and edit parsed data.
5. Save into SwiftData profile records.
6. Add a target job description.
7. Convene AI Council for tailoring recommendations.

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
