import SwiftData
import SwiftUI

struct JobDescriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JobDescription.updatedAt, order: .reverse) private var savedJobs: [JobDescription]

    @State private var title = ""
    @State private var company = ""
    @State private var rawText = ""

    var body: some View {
        Form {
            Section("Current Job Description") {
                TextField("Role title", text: $title)
                TextField("Company", text: $company)
                TextEditor(text: $rawText)
                    .frame(minHeight: 180)
                Button("Save Job Description", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Saved") {
                if savedJobs.isEmpty {
                    Text("No saved job descriptions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(savedJobs) { job in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(job.displayTitle)
                                .font(.headline)
                            Text(job.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Job Description")
    }

    private func save() {
        let normalizedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return }

        let job = JobDescription(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            company: company.trimmingCharacters(in: .whitespacesAndNewlines),
            rawText: normalizedText,
            extractedSkills: extractSkills(from: normalizedText),
            updatedAt: .now
        )
        modelContext.insert(job)
        try? modelContext.save()
    }

    private func extractSkills(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;\n")
        let words = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 2 }

        var unique: [String] = []
        for word in words where unique.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) == false {
            unique.append(word)
            if unique.count >= 20 { break }
        }
        return unique
    }
}

#Preview {
    JobDescriptionView()
}
