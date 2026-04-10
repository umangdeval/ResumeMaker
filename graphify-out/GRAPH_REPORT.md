# Graph Report - .  (2026-04-10)

## Corpus Check
- 52 files · ~35,430 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 481 nodes · 683 edges · 36 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## God Nodes (most connected - your core abstractions)
1. `ResumeResultParser` - 20 edges
2. `ResumeContentParser` - 16 edges
3. `ResumeParserViewModel` - 11 edges
4. `LaTeXTextExtractor` - 11 edges
5. `ExperienceEntryExtractor` - 11 edges
6. `Route` - 10 edges
7. `ParseConfidence` - 10 edges
8. `DoclingBackendService` - 10 edges
9. `DoclingBackendServiceError` - 9 edges
10. `ProfileView` - 9 edges

## Surprising Connections (you probably didn't know these)
- `AICouncilView` --inherits--> `View`  [EXTRACTED]
  ResumeForge/Features/AICouncil/AICouncilView.swift →   _Bridges community 2 → community 1_
- `ProfileView` --inherits--> `View`  [EXTRACTED]
  ResumeForge/Features/Profile/ProfileView.swift →   _Bridges community 2 → community 14_
- `AIServiceProtocol` --inherits--> `Sendable`  [EXTRACTED]
  ResumeForge/Core/Services/AIServiceProtocol.swift →   _Bridges community 4 → community 6_
- `ParsedDateRange` --inherits--> `Sendable`  [EXTRACTED]
  ResumeForge/Features/ResumeParser/Services/DateRangeParser.swift →   _Bridges community 4 → community 17_
- `OpenRouterRequest` --inherits--> `Encodable`  [EXTRACTED]
  ResumeForge/Core/Services/OpenRouterService.swift →   _Bridges community 6 → community 0_

## Communities

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (30): AnthropicMessage, AnthropicRequest, AnthropicResponse, AnthropicService, AnthropicStreamEvent, Content, Delta, Decodable (+22 more)

### Community 1 - "Community 1"
Cohesion: 0.05
Nodes (38): AICouncilView, CodingKeys, actionPlan, criticalImprovements, tailoredKeywords, topStrengths, CouncilResponse, CodingKeys (+30 more)

### Community 2 - "Community 2"
Cohesion: 0.06
Nodes (28): CreateTab, DashboardTab, DocumentsTab, PlaceholderTabView, ProfileTab, RootTabView, SettingsTab, EducationEditView (+20 more)

### Community 3 - "Community 3"
Cohesion: 0.07
Nodes (24): DoclingExtractionError, emptyResult, moduleNotAvailable, parseFailure, DoclingPDFExtractor, Error, KeychainError, encodingFailed (+16 more)

### Community 4 - "Community 4"
Cohesion: 0.07
Nodes (28): AIPromptRequest, Comparable, FileImportError, accessDenied, unreadable, unsupportedType, FileImportService, ImportedFile (+20 more)

### Community 5 - "Community 5"
Cohesion: 0.07
Nodes (4): DateRangeParserTests, LaTeXTextExtractorTests, ResumeContentParserContactTests, ResumeResultParserTests

### Community 6 - "Community 6"
Cohesion: 0.12
Nodes (12): AIServiceError, invalidResponse, missingAPIKey, networkError, rateLimited, serverError, AIServiceProtocol, OllamaGenerateRequest (+4 more)

### Community 7 - "Community 7"
Cohesion: 0.13
Nodes (12): DoclingBackendExtractResponse, DoclingBackendHealthResponse, DoclingBackendService, DoclingBackendServiceError, backendError, backendScriptNotFound, invalidResponse, launchFailed (+4 more)

### Community 8 - "Community 8"
Cohesion: 0.12
Nodes (10): Equatable, PythonEnvironmentStatus, ResumeParserState, idle, importing, parsing, review, saved (+2 more)

### Community 9 - "Community 9"
Cohesion: 0.26
Nodes (1): ResumeResultParser

### Community 10 - "Community 10"
Cohesion: 0.21
Nodes (2): ResumeContentParser, Section

### Community 11 - "Community 11"
Cohesion: 0.13
Nodes (11): Hashable, Route, aiCouncil, coverLetter, export, jobDescription, parseResume, profile (+3 more)

### Community 12 - "Community 12"
Cohesion: 0.25
Nodes (3): DateAnchor, EntryResult, ExperienceEntryExtractor

### Community 13 - "Community 13"
Cohesion: 0.21
Nodes (7): AICouncelViewModel, AICouncilState, analyzing, complete, error, idle, AICounselService

### Community 14 - "Community 14"
Cohesion: 0.35
Nodes (3): EducationRowView, ExperienceRowView, ProfileView

### Community 15 - "Community 15"
Cohesion: 0.36
Nodes (1): ProfileViewModel

### Community 16 - "Community 16"
Cohesion: 0.57
Nodes (7): build_parser(), cmd_extract(), cmd_health(), _emit(), _extract_text(), _import_docling_parse(), main()

### Community 17 - "Community 17"
Cohesion: 0.43
Nodes (2): DateRangeParser, ParsedDateRange

### Community 18 - "Community 18"
Cohesion: 0.33
Nodes (1): StringExtensionTests

### Community 19 - "Community 19"
Cohesion: 0.4
Nodes (1): RouterTests

### Community 20 - "Community 20"
Cohesion: 0.4
Nodes (1): KeychainServiceTests

### Community 21 - "Community 21"
Cohesion: 0.5
Nodes (1): View

### Community 22 - "Community 22"
Cohesion: 0.5
Nodes (2): App, ResumeForgeApp

### Community 23 - "Community 23"
Cohesion: 0.67
Nodes (1): Experience

### Community 24 - "Community 24"
Cohesion: 0.67
Nodes (1): UserProfile

### Community 25 - "Community 25"
Cohesion: 0.67
Nodes (1): CoverLetter

### Community 26 - "Community 26"
Cohesion: 0.67
Nodes (1): Education

### Community 27 - "Community 27"
Cohesion: 0.67
Nodes (1): Date

### Community 28 - "Community 28"
Cohesion: 1.0
Nodes (1): String

### Community 29 - "Community 29"
Cohesion: 1.0
Nodes (0): 

### Community 30 - "Community 30"
Cohesion: 1.0
Nodes (0): 

### Community 31 - "Community 31"
Cohesion: 1.0
Nodes (0): 

### Community 32 - "Community 32"
Cohesion: 1.0
Nodes (0): 

### Community 33 - "Community 33"
Cohesion: 1.0
Nodes (0): 

### Community 34 - "Community 34"
Cohesion: 1.0
Nodes (0): 

### Community 35 - "Community 35"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **72 isolated node(s):** `profile`, `parseResume`, `jobDescription`, `aiCouncil`, `resumeBuilder` (+67 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 28`** (2 nodes): `String+Extensions.swift`, `String`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 29`** (1 nodes): `SettingsPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 30`** (1 nodes): `CoverLetterPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 31`** (1 nodes): `JobDescriptionPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 32`** (1 nodes): `AICouncilPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 33`** (1 nodes): `ProfilePlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 34`** (1 nodes): `ExportPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 35`** (1 nodes): `ResumeBuilderPlaceholder.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `LLMProvider` connect `Community 1` to `Community 2`?**
  _High betweenness centrality (0.092) - this node is a cross-community bridge._
- **Why does `KeychainError` connect `Community 3` to `Community 1`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **Why does `AICouncilView` connect `Community 1` to `Community 2`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **What connects `profile`, `parseResume`, `jobDescription` to the rest of the system?**
  _72 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._