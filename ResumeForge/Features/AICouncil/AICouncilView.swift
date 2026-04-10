import SwiftUI

struct AICouncilView: View {
    @State private var viewModel = AICouncelViewModel()
    @State private var resumeText = ""
    @State private var jobDescription = ""
    @State private var isAnalyzing = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Resume")) {
                    TextEditor(text: $resumeText)
                        .frame(height: 120)
                        .lineLimit(10)
                }

                Section(header: Text("Job Description")) {
                    TextEditor(text: $jobDescription)
                        .frame(height: 120)
                        .lineLimit(10)
                }

                Section {
                    Button(action: {
                        Task {
                            await viewModel.runCouncil(
                                resumeText: resumeText,
                                jobDescription: jobDescription
                            )
                        }
                    }) {
                        if viewModel.state == .analyzing {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("AI Council Analyzing...")
                            }
                        } else {
                            Text("Consult AI Council")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .disabled(resumeText.isEmpty || jobDescription.isEmpty || viewModel.state == .analyzing)
                }

                if let output = viewModel.councilOutput {
                    Section(header: Text("Council Recommendation")) {
                        VStack(alignment: .leading, spacing: 12) {
                            if let decoded = try? JSONDecoder().decode(CouncilResponse.self, from: output.data(using: .utf8) ?? Data()) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if !decoded.topStrengths.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("✨ Top Strengths")
                                                .font(.headline)
                                                .foregroundColor(.green)
                                            ForEach(decoded.topStrengths, id: \.self) { strength in
                                                Text("• \(strength)")
                                                    .font(.caption)
                                            }
                                        }
                                    }

                                    if !decoded.criticalImprovements.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("🎯 Critical Improvements")
                                                .font(.headline)
                                                .foregroundColor(.orange)
                                            ForEach(decoded.criticalImprovements, id: \.self) { improvement in
                                                Text("• \(improvement)")
                                                    .font(.caption)
                                            }
                                        }
                                    }

                                    if !decoded.tailoredKeywords.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("🔑 Tailored Keywords")
                                                .font(.headline)
                                                .foregroundColor(.blue)
                                            Text(decoded.tailoredKeywords.joined(separator: ", "))
                                                .font(.caption)
                                        }
                                    }

                                    if !decoded.actionPlan.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("📋 Action Plan")
                                                .font(.headline)
                                                .foregroundColor(.purple)
                                            ForEach(Array(decoded.actionPlan.enumerated()), id: \.offset) { offset, action in
                                                Text("\(offset + 1). \(action)")
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                }
                            } else {
                                // Raw output if parsing fails
                                Text(output)
                                    .font(.caption)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("AI Council")
        }
    }
}

struct CouncilResponse: Codable {
    let topStrengths: [String]
    let criticalImprovements: [String]
    let tailoredKeywords: [String]
    let actionPlan: [String]

    enum CodingKeys: String, CodingKey {
        case topStrengths = "top_strengths"
        case criticalImprovements = "critical_improvements"
        case tailoredKeywords = "tailored_keywords"
        case actionPlan = "action_plan"
    }
}

#Preview {
    AICouncilView()
}
