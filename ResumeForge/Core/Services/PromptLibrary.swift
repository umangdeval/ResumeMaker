import Foundation

/// Centralised prompt templates used by the parser, AI Council, cover letter, and resume builder.
/// All AI calls should pull prompts from here so they stay consistent and easy to update.
enum PromptLibrary {

    // MARK: - LaTeX Extraction

    static let latexExtractionSystem = """
    You are a data extraction specialist.
    Return ONLY valid JSON — no markdown, no code fences, no comments.
    """

    static func latexExtractionUser(latexSource: String) -> String {
        """
        Convert this raw LaTeX resume into JSON with this exact shape:
        {
          "name": "", "email": "", "phone": "", "linkedin": "", "github": "",
          "website": "", "summary": "", "skills": [],
          "experiences": [{"company":"","title":"","dateRange":"","bulletPoints":[]}],
          "education": [{"institution":"","degree":"","field":"","graduationDate":"","gpa":""}],
          "projects": [{"name":"","year":"","bulletPoints":[]}]
        }
        Strip all LaTeX commands (\\textbf, \\hfill, \\begin, etc.).
        LaTeX source:
        \(latexSource)
        """
    }

    // MARK: - Style Analysis

    static let styleAnalysisSystem = """
    You are a writing style analyst. Analyse the sample and return a concise
    list of tone descriptors (e.g. "Formal", "First-person narrative",
    "Direct call-to-action closing"). Return plain text, no JSON.
    """

    static func styleAnalysisUser(sample: String) -> String {
        "Analyse the writing style of this cover letter sample:\n\n\(sample)"
    }

    // MARK: - Cover Letter

    static func coverLetterUser(profile: UserProfile, job: JobDescription, styleTraits: String) -> String {
        """
        Write a professional cover letter for this candidate applying to the role below.
        Tone guidelines derived from their past writing: \(styleTraits)

        Candidate: \(profile.fullName)
        Role: \(job.title) at \(job.company)
        Job description:
        \(job.rawText)
        """
    }

    static let coverLetterSystem = "You are an expert cover letter writer."

    // MARK: - Resume Builder

    static func resumeBuilderUser(profile: UserProfile, job: JobDescription, synthesis: String) -> String {
        """
        Using the AI Council recommendations below, rewrite the candidate's resume
        tailored for the target role. Return the full resume as plain text only.

        AI Council recommendations:
        \(synthesis)

        Candidate: \(profile.fullName)
        Summary: \(profile.summary)
        Target role: \(job.title) at \(job.company)
        """
    }

    static let resumeBuilderSystem = "You are an expert resume writer. Return the full resume as plain text."
}
