import Foundation

struct CouncilPrompts {
    static let analysisSystemPrompt = """
    <role>You are an elite resume consultant and hiring strategist.</role>
    <goal>Evaluate fit between a candidate resume and a job description.</goal>
    <requirements>
      <item>Be specific and actionable.</item>
      <item>Reference exact resume evidence and exact job requirements.</item>
      <item>Provide concrete bullet rewrites when suggesting improvements.</item>
      <item>Prioritize recommendations by hiring impact.</item>
    </requirements>
    <output>
      <section name=\"fit_assessment\" />
      <section name=\"missing_requirements\" />
      <section name=\"emphasis_opportunities\" />
      <section name=\"bullet_improvements\" />
      <section name=\"keyword_optimization\" />
    </output>
    """

    static let synthesisSystemPrompt = """
    <role>You are the AI Council synthesizer.</role>
    <goal>Merge multiple resume analyses into one prioritized recommendation plan.</goal>
    <requirements>
      <item>Identify where models agree and explicitly list the agreeing models.</item>
      <item>Resolve contradictions using the strongest evidence-backed argument.</item>
      <item>Produce a single prioritized plan grouped into Critical, Important, Nice to Have.</item>
      <item>Keep recommendations practical and implementation-ready.</item>
    </requirements>
    <output_format>
      Return strict JSON with this shape:
      {
        "recommendations": [
          {
            "priority": "Critical|Important|Nice to Have",
            "suggestion": "...",
            "agreedModels": ["..."]
          }
        ],
        "summary": "..."
      }
    </output_format>
    """

    static func buildAnalysisUserPrompt(profile: UserProfile, jobDescription: JobDescription) -> String {
        let experienceXML = profile.experiences.map { exp in
            let endDate = exp.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "Present"
            return """
            <experience>
              <title>\(xmlEscaped(exp.title))</title>
              <company>\(xmlEscaped(exp.company))</company>
              <dateRange>\(xmlEscaped("\(exp.startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate)"))</dateRange>
              <description>\(xmlEscaped(exp.jobDescription))</description>
              <bullets>\(xmlEscaped(exp.bulletPoints.joined(separator: " | ")))</bullets>
            </experience>
            """
        }.joined(separator: "\n")

        let educationXML = profile.education.map { edu in
            return """
            <education>
              <institution>\(xmlEscaped(edu.institution))</institution>
              <degree>\(xmlEscaped(edu.degree))</degree>
              <field>\(xmlEscaped(edu.field))</field>
              <graduationDate>\(xmlEscaped(edu.graduationDate.formatted(date: .abbreviated, time: .omitted)))</graduationDate>
            </education>
            """
        }.joined(separator: "\n")

        return """
        <analysis_request>
          <candidate_profile>
            <name>\(xmlEscaped(profile.fullName))</name>
            <summary>\(xmlEscaped(profile.summary))</summary>
            <skills>\(xmlEscaped(profile.skills.joined(separator: ", ")))</skills>
            <experience_list>
            \(experienceXML)
            </experience_list>
            <education_list>
            \(educationXML)
            </education_list>
          </candidate_profile>
          <target_job>
            <title>\(xmlEscaped(jobDescription.title))</title>
            <company>\(xmlEscaped(jobDescription.company))</company>
            <description>\(xmlEscaped(jobDescription.rawText))</description>
            <skills>\(xmlEscaped(jobDescription.extractedSkills.joined(separator: ", ")))</skills>
          </target_job>
        </analysis_request>
        """
    }

    static func buildSynthesisUserPrompt(analyses: [LLMResponse]) -> String {
        let modelsXML = analyses.map { analysis in
            return """
            <analysis>
              <provider>\(analysis.provider.displayName)</provider>
              <model>\(xmlEscaped(analysis.model))</model>
              <latency_seconds>\(String(format: "%.2f", analysis.latency))</latency_seconds>
              <content>\(xmlEscaped(analysis.content))</content>
            </analysis>
            """
        }.joined(separator: "\n")

        return """
        <synthesis_request>
          <analyses>
          \(modelsXML)
          </analyses>
          <deliverable>
            Produce one prioritized recommendation plan and include model agreement tags.
          </deliverable>
        </synthesis_request>
        """
    }

    private static func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
