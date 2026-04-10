# Graph Report - .  (2026-04-10)

## Corpus Check
- Corpus is ~12,234 words - fits in a single context window. You may not need a graph.

## Summary
- 392 nodes · 515 edges · 36 communities detected
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.84)
- Token cost: 3,200 input · 2,800 output

## God Nodes (most connected - your core abstractions)
1. `Umang Deval (Person)` - 18 edges
2. `ResumeContentParser` - 17 edges
3. `LaTeXTextExtractor` - 11 edges
4. `Route` - 10 edges
5. `DoclingBackendService` - 10 edges
6. `AI Council Pattern` - 10 edges
7. `DoclingBackendServiceError` - 9 edges
8. `ResumeForge Project Overview` - 9 edges
9. `CodingKeys` - 8 edges
10. `GeminiService` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Python (Programming Language)` --semantically_similar_to--> `Python Virtual Environment (.venv)`  [INFERRED] [semantically similar]
  example/UmangDevalResume.pdf → README.md
- `Google Gemini LLM Provider` --semantically_similar_to--> `Google Vertex AI / Gemini (AI Integration)`  [INFERRED] [semantically similar]
  CLAUDE.md → example/UmangDevalResume.pdf
- `AICouncil Feature Module` --semantically_similar_to--> `Google Vertex AI / Gemini (AI Integration)`  [INFERRED] [semantically similar]
  CLAUDE.md → example/UmangDevalResume.pdf
- `Umang Deval (Person)` --conceptually_related_to--> `ResumeForge Project Overview`  [INFERRED]
  example/UmangDevalResume.pdf → CLAUDE.md
- `PDFKit (Native PDF Parsing)` --semantically_similar_to--> `Native PDF Extraction Fallback`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md

## Hyperedges (group relationships)
- **AI Council Multi-LLM Orchestration Flow** — claude_ai_council, claude_llm_openai, claude_llm_anthropic, claude_llm_gemini, claude_feature_ai_council [EXTRACTED 1.00]
- **PDF Parsing Strategy with Docling and Native Fallback** — readme_pdf_parsing, readme_docling_backend, readme_native_pdf_fallback, claude_pdfkit [EXTRACTED 0.95]
- **Resume Parsing -> AI Council -> Output Generation Pipeline** — claude_feature_resume_parser, claude_feature_job_description, claude_ai_council, claude_feature_resume_builder, claude_feature_cover_letter [INFERRED 0.88]

## Communities

### Community 0 - "Anthropic API Client"
Cohesion: 0.09
Nodes (21): AnthropicMessage, AnthropicRequest, AnthropicResponse, AnthropicService, AnthropicStreamEvent, Content, Delta, Decodable (+13 more)

### Community 1 - "AI Service Errors"
Cohesion: 0.07
Nodes (29): AIServiceError, invalidResponse, missingAPIKey, networkError, rateLimited, serverError, DoclingExtractionError, emptyResult (+21 more)

### Community 2 - "Architecture & Feature Map"
Cohesion: 0.07
Nodes (32): AI Council Pattern, Core Models (SwiftData), Core Services (Network/AI/Storage), Export Module (PDF/LaTeX/DOCX), AICouncil Feature Module, CoverLetter Feature Module, Export Feature Module, JobDescription Feature Module (+24 more)

### Community 3 - "AI Service Protocol & File Import"
Cohesion: 0.09
Nodes (22): AIPromptRequest, AIServiceProtocol, FileImportError, accessDenied, unreadable, unsupportedType, FileImportService, ImportedFile (+14 more)

### Community 4 - "Navigation & Tab Views"
Cohesion: 0.11
Nodes (22): CreateTab, DashboardTab, DocumentsTab, PlaceholderTabView, RootTabView, SettingsTab, ErrorBanner, ErrorView (+14 more)

### Community 5 - "LLM Request Codable Schema"
Cohesion: 0.08
Nodes (21): CodingKeys, maxTokens, messages, model, stream, system, CaseIterable, Codable (+13 more)

### Community 6 - "Docling Python Backend"
Cohesion: 0.13
Nodes (12): DoclingBackendExtractResponse, DoclingBackendHealthResponse, DoclingBackendService, DoclingBackendServiceError, backendError, backendScriptNotFound, invalidResponse, launchFailed (+4 more)

### Community 7 - "Resume Parser Tests"
Cohesion: 0.09
Nodes (3): DateRangeParserTests, LaTeXTextExtractorTests, ResumeContentParserContactTests

### Community 8 - "Resume Content Parser"
Cohesion: 0.2
Nodes (2): ResumeContentParser, Section

### Community 9 - "Parser State & ViewModel"
Cohesion: 0.14
Nodes (10): Equatable, PythonEnvironmentStatus, ResumeParserState, idle, importing, parsing, review, saved (+2 more)

### Community 10 - "Umang Deval Resume"
Cohesion: 0.18
Nodes (18): Sheridan College – Diploma in Computer Programming, University of Guelph – BSc Computer Science, IT Head at Anand Niketan, Software Development Intern at Ledger Software, Guest Registration Staff at UoGuelph Housing, Retail Associate at Walmart Canada, Blackjack GUI (JavaFX Project), QuickLearn – AI-Powered Microlearning Platform (+10 more)

### Community 11 - "App Routing"
Cohesion: 0.13
Nodes (11): Hashable, Route, aiCouncil, coverLetter, export, jobDescription, parseResume, profile (+3 more)

### Community 12 - "LaTeX Text Extraction"
Cohesion: 0.35
Nodes (1): LaTeXTextExtractor

### Community 13 - "Gemini API Client"
Cohesion: 0.33
Nodes (2): GeminiRequest, GeminiService

### Community 14 - "Docling Python Script"
Cohesion: 0.57
Nodes (7): build_parser(), cmd_extract(), cmd_health(), _emit(), _extract_text(), _import_docling_parse(), main()

### Community 15 - "Date Range Parser"
Cohesion: 0.43
Nodes (2): DateRangeParser, ParsedDateRange

### Community 16 - "String Extension Tests"
Cohesion: 0.33
Nodes (1): StringExtensionTests

### Community 17 - "App Router Tests"
Cohesion: 0.4
Nodes (1): RouterTests

### Community 18 - "Keychain Service Tests"
Cohesion: 0.4
Nodes (1): KeychainServiceTests

### Community 19 - "SwiftUI View Extensions"
Cohesion: 0.5
Nodes (1): View

### Community 20 - "App Entry Point"
Cohesion: 0.5
Nodes (2): App, ResumeForgeApp

### Community 21 - "Experience Model"
Cohesion: 0.67
Nodes (1): Experience

### Community 22 - "User Profile Model"
Cohesion: 0.67
Nodes (1): UserProfile

### Community 23 - "Cover Letter Model"
Cohesion: 0.67
Nodes (1): CoverLetter

### Community 24 - "Education Model"
Cohesion: 0.67
Nodes (1): Education

### Community 25 - "Date Extensions"
Cohesion: 0.67
Nodes (1): Date

### Community 26 - "String Extensions"
Cohesion: 1.0
Nodes (1): String

### Community 27 - "Settings Placeholder"
Cohesion: 1.0
Nodes (0): 

### Community 28 - "Cover Letter Placeholder"
Cohesion: 1.0
Nodes (0): 

### Community 29 - "Job Description Placeholder"
Cohesion: 1.0
Nodes (0): 

### Community 30 - "AI Council Placeholder"
Cohesion: 1.0
Nodes (0): 

### Community 31 - "Profile Placeholder"
Cohesion: 1.0
Nodes (0): 

### Community 32 - "Export Placeholder"
Cohesion: 1.0
Nodes (0): 

### Community 33 - "Resume Builder Placeholder"
Cohesion: 1.0
Nodes (0): 

### Community 34 - "Swift Package Manager"
Cohesion: 1.0
Nodes (1): Swift Package Manager (SPM)

### Community 35 - "Profile Feature Module"
Cohesion: 1.0
Nodes (1): Profile Feature Module

## Knowledge Gaps
- **77 isolated node(s):** `profile`, `parseResume`, `jobDescription`, `aiCouncil`, `resumeBuilder` (+72 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `String Extensions`** (2 nodes): `String+Extensions.swift`, `String`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Settings Placeholder`** (1 nodes): `SettingsPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cover Letter Placeholder`** (1 nodes): `CoverLetterPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Job Description Placeholder`** (1 nodes): `JobDescriptionPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `AI Council Placeholder`** (1 nodes): `AICouncilPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Profile Placeholder`** (1 nodes): `ProfilePlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Export Placeholder`** (1 nodes): `ExportPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Resume Builder Placeholder`** (1 nodes): `ResumeBuilderPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Swift Package Manager`** (1 nodes): `Swift Package Manager (SPM)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Profile Feature Module`** (1 nodes): `Profile Feature Module`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AIServiceError` connect `AI Service Errors` to `AI Service Protocol & File Import`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `DoclingBackendServiceError` connect `Docling Python Backend` to `AI Service Errors`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **What connects `profile`, `parseResume`, `jobDescription` to the rest of the system?**
  _77 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Anthropic API Client` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._
- **Should `AI Service Errors` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._
- **Should `Architecture & Feature Map` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._
- **Should `AI Service Protocol & File Import` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._