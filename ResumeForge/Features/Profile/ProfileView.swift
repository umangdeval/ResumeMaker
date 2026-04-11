import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProfileViewModel()
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if let profile = viewModel.profile {
                    VStack(spacing: 18) {
                        importResumeCard
                        profileForm(profile)
                    }
                } else {
                    VStack(spacing: 18) {
                        importResumeCard
                        ProgressView("Loading profile…")
                            .tint(.white)
                            .foregroundStyle(.white)
                    }
                }
            }
            .appScreenBackground()
            .navigationTitle("Profile")
            .tint(AppTheme.blue)
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear", role: .destructive) { showClearConfirm = true }
                }
            }
            .confirmationDialog("Delete all profile data?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    viewModel.clearProfile(context: modelContext)
                }
            }
            .onAppear { viewModel.load(context: modelContext) }
            .sheet(isPresented: $viewModel.isAddingExperience) {
                ExperienceEditView(experience: Experience(), isNew: true) { exp in
                    viewModel.addExperience(exp, context: modelContext)
                }
            }
            .sheet(item: $viewModel.editingExperience) { exp in
                ExperienceEditView(experience: exp, isNew: false) { _ in
                    viewModel.save(context: modelContext)
                }
            }
            .sheet(isPresented: $viewModel.isAddingEducation) {
                EducationEditView(education: Education(), isNew: true) { edu in
                    viewModel.addEducation(edu, context: modelContext)
                }
            }
            .sheet(item: $viewModel.editingEducation) { edu in
                EducationEditView(education: edu, isNew: false) { _ in
                    viewModel.save(context: modelContext)
                }
            }
        }
    }

    private func profileForm(_ profile: UserProfile) -> some View {
        Form {
            contactSection(profile)
            summarySection(profile)
            skillsSection(profile)
            experienceSection(profile)
            educationSection(profile)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
    }

    private var importResumeCard: some View {
        NavigationLink {
            ResumeParserView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step 1")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundStyle(AppTheme.blue)
                    Text("Import / Parse Resume")
                        .font(AppTheme.sectionTitle)
                        .foregroundStyle(AppTheme.text)
                }
                Text("Extract and normalize your resume data.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .appCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Form sections

private extension ProfileView {
    func save() { viewModel.save(context: modelContext) }

    func contactSection(_ profile: UserProfile) -> some View {
        Section("Contact") {
            TextField("Full Name", text: Binding(get: { profile.fullName }, set: { profile.fullName = $0; save() }))
            TextField("Email", text: Binding(get: { profile.email }, set: { profile.email = $0; save() }))
                .autocorrectionDisabled()
            TextField("Phone", text: Binding(get: { profile.phone }, set: { profile.phone = $0; save() }))
            TextField("LinkedIn URL", text: Binding(get: { profile.linkedIn ?? "" }, set: { profile.linkedIn = $0.isEmpty ? nil : $0; save() }))
                .autocorrectionDisabled()
            TextField("GitHub URL", text: Binding(get: { profile.github ?? "" }, set: { profile.github = $0.isEmpty ? nil : $0; save() }))
                .autocorrectionDisabled()
            TextField("Website URL", text: Binding(get: { profile.website ?? "" }, set: { profile.website = $0.isEmpty ? nil : $0; save() }))
                .autocorrectionDisabled()
        }
    }

    func summarySection(_ profile: UserProfile) -> some View {
        Section("Summary") {
            TextEditor(text: Binding(get: { profile.summary }, set: { profile.summary = $0; save() }))
                .frame(minHeight: 80)
        }
    }

    func skillsSection(_ profile: UserProfile) -> some View {
        Section("Skills") {
            HStack {
                TextField("Add skill…", text: $viewModel.newSkill)
                    .onSubmit { viewModel.addSkill(context: modelContext) }
                Button("Add") { viewModel.addSkill(context: modelContext) }
                    .disabled(viewModel.newSkill.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ForEach(profile.skills, id: \.self) { skill in
                HStack {
                    Text(skill)
                    Spacer()
                    Button(role: .destructive) {
                        viewModel.removeSkill(skill, context: modelContext)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    func experienceSection(_ profile: UserProfile) -> some View {
        Section("Experience") {
            ForEach(profile.experiences.sorted { $0.startDate > $1.startDate }) { exp in
                ExperienceRowView(experience: exp)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.editingExperience = exp }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteExperience(exp, context: modelContext)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
            }
            Button { viewModel.isAddingExperience = true } label: {
                Label("Add Experience", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.blue)
        }
    }

    func educationSection(_ profile: UserProfile) -> some View {
        Section("Education") {
            ForEach(profile.education.sorted { $0.graduationDate > $1.graduationDate }) { edu in
                EducationRowView(education: edu)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.editingEducation = edu }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteEducation(edu, context: modelContext)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
            }
            Button { viewModel.isAddingEducation = true } label: {
                Label("Add Education", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.blue)
        }
    }
}

// MARK: - Row views

private struct ExperienceRowView: View {
    let experience: Experience
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(experience.title).font(.headline)
            Text(experience.company).font(.subheadline).foregroundStyle(.secondary)
            Text(Date.dateRangeString(start: experience.startDate, end: experience.endDate, isCurrent: experience.isCurrent))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct EducationRowView: View {
    let education: Education
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(education.degree) in \(education.field)").font(.headline)
            Text(education.institution).font(.subheadline).foregroundStyle(.secondary)
            Text(education.graduationDate.formatted(.dateTime.month(.abbreviated).year()))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
