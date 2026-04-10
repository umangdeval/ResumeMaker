import SwiftUI
import SwiftData

struct ExperienceEditView: View {
    @Bindable var experience: Experience
    @Environment(\.modelContext) private var context
    @State private var newBullet = ""

    var body: some View {
        Form {
            Section("Role") {
                TextField("Job Title", text: $experience.title)
                TextField("Company", text: $experience.company)
            }

            Section("Dates") {
                DatePicker("Start Date", selection: $experience.startDate, displayedComponents: .date)
                Toggle("Currently working here", isOn: Binding(
                    get: { experience.isCurrent },
                    set: { experience.endDate = $0 ? nil : .now }
                ))
                if !experience.isCurrent {
                    DatePicker("End Date",
                               selection: Binding(
                                get: { experience.endDate ?? .now },
                                set: { experience.endDate = $0 }
                               ),
                               displayedComponents: .date)
                }
            }

            Section("Description") {
                TextEditor(text: $experience.jobDescription)
                    .frame(minHeight: 60)
            }

            Section {
                ForEach(experience.bulletPoints.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        TextField("Bullet point", text: $experience.bulletPoints[i], axis: .vertical)
                            .lineLimit(2...5)
                        Button(role: .destructive) {
                            experience.bulletPoints.remove(at: i)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundStyle(.secondary)
                    TextField("Add bullet…", text: $newBullet, axis: .vertical)
                        .lineLimit(2...5)
                        .onSubmit { commitBullet() }
                    Button(action: commitBullet) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newBullet.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Bullet Points")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(experience.title.isEmpty ? "New Experience" : experience.title)
        .onChange(of: experience.title) { _, _ in saveIfNeeded() }
        .onChange(of: experience.company) { _, _ in saveIfNeeded() }
        .onChange(of: experience.bulletPoints) { _, _ in saveIfNeeded() }
    }

    private func commitBullet() {
        let trimmed = newBullet.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        experience.bulletPoints.append(trimmed)
        newBullet = ""
    }

    private func saveIfNeeded() {
        try? context.save()
    }
}
