import SwiftUI
import SwiftData

struct EducationEditView: View {
    @Bindable var education: Education
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section("Institution") {
                TextField("University / School", text: $education.institution)
            }

            Section("Degree") {
                TextField("Degree (e.g. B.Sc, M.Eng)", text: $education.degree)
                TextField("Field of Study", text: $education.field)
            }

            Section("Details") {
                DatePicker("Graduation Date",
                           selection: $education.graduationDate,
                           displayedComponents: .date)
                HStack {
                    Text("GPA")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("Optional", text: Binding(
                        get: { education.gpa ?? "" },
                        set: { education.gpa = $0.isEmpty ? nil : $0 }
                    ))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(education.institution.isEmpty ? "New Education" : education.institution)
        .onChange(of: education.institution) { _, _ in try? context.save() }
        .onChange(of: education.degree) { _, _ in try? context.save() }
        .onChange(of: education.field) { _, _ in try? context.save() }
        .onChange(of: education.graduationDate) { _, _ in try? context.save() }
        .onChange(of: education.gpa) { _, _ in try? context.save() }
    }
}
