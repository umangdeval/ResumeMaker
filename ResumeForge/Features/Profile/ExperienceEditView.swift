import SwiftUI

struct ExperienceEditView: View {
    @Environment(\.dismiss) private var dismiss

    let experience: Experience
    let isNew: Bool
    let onSave: (Experience) -> Void

    @State private var title: String
    @State private var company: String
    @State private var startDate: Date
    @State private var isCurrent: Bool
    @State private var endDate: Date
    @State private var description: String
    @State private var bulletPoints: [String]
    @State private var newBullet = ""

    init(experience: Experience, isNew: Bool, onSave: @escaping (Experience) -> Void) {
        self.experience = experience
        self.isNew = isNew
        self.onSave = onSave
        _title = State(initialValue: experience.title)
        _company = State(initialValue: experience.company)
        _startDate = State(initialValue: experience.startDate)
        _isCurrent = State(initialValue: experience.endDate == nil)
        _endDate = State(initialValue: experience.endDate ?? .now)
        _description = State(initialValue: experience.jobDescription)
        _bulletPoints = State(initialValue: experience.bulletPoints)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Position") {
                    TextField("Job Title", text: $title)
                    TextField("Company", text: $company)
                }
                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    Toggle("Current Position", isOn: $isCurrent)
                    if !isCurrent {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    }
                }
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 60)
                }
                bulletSection
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "Add Experience" : "Edit Experience")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: commitAndSave)
                        .disabled(title.isEmpty || company.isEmpty)
                }
            }
        }
    }

    private var bulletSection: some View {
        Section("Highlights") {
            ForEach(bulletPoints, id: \.self) { bullet in
                Text(bullet).font(.subheadline)
            }
            .onDelete { bulletPoints.remove(atOffsets: $0) }
            HStack {
                TextField("Add highlight…", text: $newBullet)
                    .onSubmit(addBullet)
                Button("Add", action: addBullet)
                    .disabled(newBullet.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addBullet() {
        let trimmed = newBullet.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        bulletPoints.append(trimmed)
        newBullet = ""
    }

    private func commitAndSave() {
        experience.title = title
        experience.company = company
        experience.startDate = startDate
        experience.endDate = isCurrent ? nil : endDate
        experience.jobDescription = description
        experience.bulletPoints = bulletPoints
        onSave(experience)
        dismiss()
    }
}
