1. Resume Import & Profile Workflow
The Change: Moving from a simple text field to a structured "Parsing -> Verification -> Commit" flow for PDF and LaTeX.

Logic (The "Stage"): When a user imports a file, do not overwrite their profile immediately. Save the parsed data into a DraftProfile struct.
The UI Flow:
User selects file.
An overlay or sheet appears: "Parsing Resume..." with a progress bar.
The Review Screen: Show the parsed data in editable fields.
Cancel Button: If the user clicks "Cancel," the DraftProfile is discarded, and they are returned to the previous state without data loss.
Clear Button: A separate action inside the Profile view that wipes the SwiftData container for UserProfile. Use a confirmationDialog to prevent accidental deletion.
2. The "AI Council" 2.0 Logic
The Change: A dynamic multi-model system that handles "Bring Your Own Key" (BYOK) gracefully, even if only one key is provided.

Minimum Requirement Logic:
The system checks available API keys (OpenAI, Anthropic, Gemini).
Scenario A (Multiple Keys): If 3 keys are present, send the prompt to all three in parallel using TaskGroup.
Scenario B (Single Key): if only one key is present (e.g., OpenAI), the "Council" generates 3 different versions by varying the System Prompt (e.g., "Perspective 1: Strict ATS Recruiter", "Perspective 2: Creative Hiring Manager", "Perspective 3: Technical Peer").
Head of Council (The "Synthesizer"):
Users select one model to be the "Head."
After the 3 responses come back, the "Head" receives a final prompt: "Here are three versions of a tailored resume prepared by our council. Combine the best elements of all three into a final, professional version."
This ensures high-quality merging of ideas.
3. LaTeX Parsing via LLM
The Change: Moving beyond regex-based parsing to use AI for high-accuracy LaTeX extraction.

Requirement: LaTeX structure is often nested (e.g., \begin{itemize}). Standard string splitting often fails.
Implementation:
Read the .tex file into a raw string.
Send a specialized, high-token-efficient prompt to the cheapest available LLM (like GPT-4o-mini or Claude Haiku).
Prompt Instruction: "Convert this raw LaTeX code into a structured JSON format containing: name, contact, list of experiences (with dates), and skills. Strip all LaTeX commands like \textbf or \hfill."
Parse the resulting JSON into your Swift Profile model.
4. Style-Guided Cover Letters
The Change: Teaching the AI "how I sound" before it writes anything.

The "Vibe" Capture: Add a section in Settings: "Style Reference."
Mechanism:
User provides a sample of a cover letter they previously wrote and liked.
The AI analyzes this sample once and creates a "Style Persona" (e.g., "Tone: Professional yet humble," "Closing style: Direct call to action").
Prompt Injection: Every time a new cover letter is generated, the prompt includes: "Use the following tone guidelines derived from the user's past writing: [Persona Traits]."
5. Detailed AI Prompt Architecture
The Change: Implementing a PromptLibrary that handles the heavy lifting.

Extraction Prompt: "You are a data extraction specialist. Take this [PDF/LaTeX] content and return only valid JSON."
Council Prompt (Individual): "Optimize this resume for this Job Description. Focus specifically on [Keywords/Skill-matching/Result-quantification]." (Each of the 3 council members gets a different focus).
Synthesis Prompt (Head of Council): "Compare the output of Member A, B, and C. Resolve contradictions and produce the most impactful final version."