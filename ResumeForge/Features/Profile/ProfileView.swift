import SwiftUI
import SwiftData

// MARK: - Root

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var vm = ProfileViewModel()

    private var profile: UserProfile {
        if let existing = profiles.first { return existing }
        let new = UserProfile()
        context.insert(new)
        return new
    }

    var body: some View {
        NavigationStack {
            Form {
                ContactSection(profile: profile)
                SummarySection(profile: profile)
                SkillsSection(profile: profile)
                ExperienceSection(profile: profile, vm: vm)
                EducationSection(profile: profile, vm: vm)
            }
            .formStyle(.grouped)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        vm.save(profile: profile, context: context)
                    } label: {
                        if vm.isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(vm.isSaving)
                }
            }
            .overlay(alignment: .bottom) {
                if vm.savedToast {
                    SavedToast()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { vm.savedToast = false }
                            }
                        }
                        .padding(.bottom, 20)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: vm.savedToast)
        }
    }
}

// MARK: - Contact

private struct ContactSection: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Section("Contact") {
            LabeledTextField("Full Name", text: $profile.fullName, icon: "person")
            LabeledTextField("Email", text: $profile.email, icon: "envelope")
                .textContentType(.emailAddress)
            LabeledTextField("Phone", text: $profile.phone, icon: "phone")
                .textContentType(.telephoneNumber)
            LabeledTextField("LinkedIn", text: Binding(
                get: { profile.linkedIn ?? "" },
                set: { profile.linkedIn = $0.isEmpty ? nil : $0 }
            ), icon: "link")
            LabeledTextField("GitHub", text: Binding(
                get: { profile.github ?? "" },
                set: { profile.github = $0.isEmpty ? nil : $0 }
            ), icon: "chevron.left.forwardslash.chevron.right")
            LabeledTextField("Website", text: Binding(
                get: { profile.website ?? "" },
                set: { profile.website = $0.isEmpty ? nil : $0 }
            ), icon: "globe")
        }
    }
}

// MARK: - Summary

private struct SummarySection: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Section("Summary") {
            TextEditor(text: $profile.summary)
                .frame(minHeight: 80)
                .font(.body)
        }
    }
}

// MARK: - Skills

private struct SkillsSection: View {
    @Bindable var profile: UserProfile
    @State private var newSkill = ""

    var body: some View {
        Section {
            ForEach(profile.skills.indices, id: \.self) { i in
                HStack {
                    TextField("Skill", text: $profile.skills[i])
                    Spacer()
                    Button(role: .destructive) {
                        profile.skills.remove(at: i)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("Add skill…", text: $newSkill)
                    .onSubmit { commitSkill() }
                Button(action: commitSkill) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newSkill.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Skills")
        }
    }

    private func commitSkill() {
        let trimmed = newSkill.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        profile.skills.append(trimmed)
        newSkill = ""
    }
}

// MARK: - Experience

private struct ExperienceSection: View {
    @Bindable var profile: UserProfile
    let vm: ProfileViewModel
    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            ForEach($profile.experiences) { $exp in
                NavigationLink {
                    ExperienceEditView(experience: exp)
                } label: {
                    ExperienceRow(experience: exp)
                }
            }
            .onDelete { offsets in
                vm.deleteExperiences(at: offsets, from: profile, context: context)
            }
            Button {
                vm.addExperience(to: profile, context: context)
            } label: {
                Label("Add Experience", systemImage: "plus")
            }
        } header: {
            Text("Experience")
        }
    }
}

private struct ExperienceRow: View {
    let experience: Experience

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(experience.title.isEmpty ? "Untitled Role" : experience.title)
                .font(.headline)
            Text(experience.company.isEmpty ? "Company" : experience.company)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(dateRangeText)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var dateRangeText: String {
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"
        let start = df.string(from: experience.startDate)
        let end = experience.isCurrent ? "Present" : experience.endDate.map { df.string(from: $0) } ?? ""
        return "\(start) – \(end)"
    }
}

// MARK: - Education

private struct EducationSection: View {
    @Bindable var profile: UserProfile
    let vm: ProfileViewModel
    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            ForEach($profile.education) { $edu in
                NavigationLink {
                    EducationEditView(education: edu)
                } label: {
                    EducationRow(education: edu)
                }
            }
            .onDelete { offsets in
                vm.deleteEducation(at: offsets, from: profile, context: context)
            }
            Button {
                vm.addEducation(to: profile, context: context)
            } label: {
                Label("Add Education", systemImage: "plus")
            }
        } header: {
            Text("Education")
        }
    }
}

private struct EducationRow: View {
    let education: Education

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(education.institution.isEmpty ? "Institution" : education.institution)
                .font(.headline)
            Text([education.degree, education.field].filter { !$0.isEmpty }.joined(separator: " in "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Shared helpers

private struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    let icon: String

    init(_ label: String, text: Binding<String>, icon: String) {
        self.label = label
        self._text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            TextField(label, text: $text)
        }
    }
}

private struct SavedToast: View {
    var body: some View {
        Label("Saved", systemImage: "checkmark.circle.fill")
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.green, in: Capsule())
            .shadow(radius: 4)
    }
}
