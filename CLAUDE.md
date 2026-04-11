# ResumeForge — Claude Code Guide

## Project Overview

ResumeForge is a native SwiftUI macOS app for 14+ that parses existing resumes (PDF/LaTeX), uses an "AI Council" of multiple LLMs to generate tailored resumes and cover letters for specific job descriptions, supports both manual and AI-assisted editing, and exports to PDF, LaTeX, and DOCX. Users bring their own API keys for each supported LLM provider; no backend is required.

---

## Technical Stack

| Concern | Choice |
|---|---|
| Platforms | iOS 17+ / macOS 14+ — universal app, single codebase |
| Language | Swift 6.0 with strict concurrency enabled |
| UI | SwiftUI only (no UIKit/AppKit unless SwiftUI has no equivalent) |
| Data | SwiftData for local persistence |
| Architecture | MVVM with `@Observable` |
| Package Manager | Swift Package Manager (SPM) |
| PDF Parsing | PDFKit (native) or PSPDFKit |
| LaTeX Parsing | Custom lightweight parser |
| Networking | `async/await` with `URLSession` |
| Export | Native PDF rendering, LaTeX string generation, DOCX via CoreXML or lightweight library |

---

## Build & Test Commands

```bash
# Build for macOS (primary target — this is a Mac app)
xcodebuild build -project 'ResumeForge.xcodeproj' -scheme ResumeForge -destination 'platform=macOS'

# Run tests
xcodebuild test -scheme ResumeForge -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Clean
xcodebuild clean -scheme ResumeForge
```

---

## Project Structure

```
ResumeForge/
├── App/                    # App entry point, app-level config
├── Features/               # Feature modules
│   ├── ResumeParser/       # PDF/LaTeX parsing
│   ├── Profile/            # User profile management
│   ├── JobDescription/     # Job description input & analysis
│   ├── AICouncil/          # Multi-LLM orchestration
│   ├── ResumeBuilder/      # Resume generation & editing
│   ├── CoverLetter/        # Cover letter generation & editing
│   ├── Export/             # PDF/LaTeX/DOCX export
│   └── Settings/           # API key management, preferences
├── Core/                   # Shared code
│   ├── Models/             # SwiftData models
│   ├── Services/           # Network, AI, storage services
│   ├── UI/                 # Shared UI components
│   └── Extensions/         # Swift extensions
├── Resources/              # Assets, fonts, sample data
└── Tests/                  # Unit & UI tests
```

---

## Coding Standards

- Use `@Observable` for all view models. **Never** use `ObservableObject` / `@Published`.
- Use `async/await` exclusively — no completion handlers.
- Use `NavigationStack` with type-safe `enum`-based routing.
- Use `@Environment` for dependency injection.
- All errors must be typed Swift `Error` enums, not `NSError`.
- Extract subviews — no SwiftUI view body should exceed ~40 lines.
- Business logic lives in ViewModels and Services, **never** in Views.
- Use Swift's `Codable` protocol for all data serialization.
- Mark `@MainActor` on view models that update UI state.

---

## IMPORTANT: Negative Constraints

- **DO NOT** use `ObservableObject`, `@Published`, or Combine publishers.
- **DO NOT** use force unwrapping (`!`) without a justifying comment.
- **DO NOT** use storyboards or XIBs.
- **DO NOT** write business logic in SwiftUI views.
- **DO NOT** use UIKit/AppKit directly unless SwiftUI has no equivalent.
- **DO NOT** store API keys in source code or UserDefaults unencrypted — use Keychain.
- **DO NOT** create files longer than 300 lines. Split into extensions or sub-components.

---

## AI Integration Notes

- Supported LLM providers: OpenAI, Anthropic, Google Gemini.
- Users supply their own API keys, stored in Keychain.
- **AI Council pattern:** multiple models independently analyze a resume + job description, then a synthesizer model merges their suggestions into a final output.
- All AI calls must be cancellable and display progress indicators.
- Token usage should be estimated and shown to users **before** expensive calls are made.

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `python3 -c "from graphify.watch import _rebuild_code; from pathlib import Path; _rebuild_code(Path('.'))"` to keep the graph current
