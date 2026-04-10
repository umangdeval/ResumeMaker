import SwiftUI

struct EducationEditView: View {
    @Environment(\.dismiss) private var dismiss

    let education: Education
    let isNew: Bool
    let onSave: (Education) -> Void

    @State private var institution: String
    @State private var degree: String
    @State private var field: String
    @State private var graduationDate: Date
    @State private var gpa: String

    init(education: Education, isNew: Bool, onSave: @escaping (Education) -> Void) {
        self.education = education
        self.isNew = isNew
        self.onSave = onSave
        _institution = State(initialValue: education.institution)
        _degree = State(initialValue: education.degree)
        _field = State(initialValue: education.field)
        _graduationDate = State(initialValue: education.graduationDate)
        _gpa = State(initialValue: education.gpa ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Institution") {
                    TextField("School / University", text: $institution)
                    TextField("Degree (e.g. Bachelor of Science)", text: $degree)
                    TextField("Field of Study", text: $field)
                }
                Section("Details") {
                    DatePicker("Graduation Date", selection: $graduationDate, displayedComponents: .date)
                    TextField("GPA (optional)", text: $gpa)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "Add Education" : "Edit Education")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: commitAndSave)
                        .disabled(institution.isEmpty || degree.isEmpty || field.isEmpty)
                }
            }
        }
    }

    private func commitAndSave() {
        education.institution = institution
        education.degree = degree
        education.field = field
        education.graduationDate = graduationDate
        education.gpa = gpa.isEmpty ? nil : gpa
        onSave(education)
        dismiss()
    }
}
