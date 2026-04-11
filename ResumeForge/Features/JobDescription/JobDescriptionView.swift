import SwiftData
import SwiftUI

struct JobDescriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JobDescription.updatedAt, order: .reverse) private var savedJobs: [JobDescription]

    @State private var title = ""
    @State private var company = ""
    @State private var rawText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                inputCard
                savedCard
            }
            .padding(20)
            .appContentWidth()
        }
        .appScreenBackground()
        .navigationTitle("Job Description")
        .tint(AppTheme.blue)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Job Description")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)

            TextField("Role title", text: $title)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.text)
                .padding(12)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 6))
            TextField("Company", text: $company)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.text)
                .padding(12)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 6))
            TextEditor(text: $rawText)
                .frame(minHeight: 190)
                .padding(8)
                .foregroundStyle(AppTheme.text)
                .scrollContentBackground(.hidden)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 6))

            Button("Save Job Description", action: save)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.blue)
                .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(18)
        .appCard()
    }

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved")
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.text)

            if savedJobs.isEmpty {
                Text("No saved job descriptions yet.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(savedJobs) { job in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.displayTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                        Text(job.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(AppTheme.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .appCard()
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
