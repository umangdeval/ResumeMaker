import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Main view

struct ResumeParserView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ResumeParserViewModel()

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            Group {
                switch viewModel.parserState {
                case .idle:
                    ImportPromptView(viewModel: viewModel)
                case .importing:
                    LoadingView(message: "Opening file picker…")
                case .parsing:
                    LoadingView(message: "Extracting text from \(viewModel.fileName)…")
                case .review:
                    ParsedReviewView(viewModel: viewModel)
                case .saving:
                    LoadingView(message: "Saving to your profile…")
                case .saved:
                    SavedConfirmationView { viewModel.parserState = .idle }
                }
            }
        }
        .fileImporter(
            isPresented: $viewModel.isShowingFilePicker,
            allowedContentTypes: ResumeFileType.supportedUTTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await viewModel.handlePickedURL(url) }
            case .failure(let err):
                viewModel.error = err
                viewModel.parserState = .idle
            }
        }
        .onChange(of: viewModel.isShowingFilePicker) { _, newValue in
            if !newValue { viewModel.handlePickerDismissed() }
        }
        .errorBanner(viewModel.error)
        .navigationTitle("Import Resume")
        .tint(AppTheme.blue)
    }
}

// MARK: - Import prompt

private struct ImportPromptView: View {
    let viewModel: ResumeParserViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            dropZoneContent
            importButton
            Spacer()
        }
        .padding()
        .appScreenBackground()
        .onDrop(of: ResumeFileType.supportedUTTypes, isTargeted: nil) { providers in
            Task { await handleDrop(providers) }
            return true
        }
    }

    private var dropZoneContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.white)
            Text("Import your existing resume")
                .font(AppTheme.heroTitle)
                .foregroundStyle(.white)
            Text("Supports PDF and LaTeX (.tex) files.\nWe'll extract your information so you can review and refine it.")
                .font(AppTheme.body)
                .foregroundStyle(.white.opacity(0.84))
                .multilineTextAlignment(.center)
            Text("Drop a file here or click Import")
                .font(AppTheme.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(20)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
    }

    private var importButton: some View {
        Button(action: viewModel.startImport) {
            Label("Import Resume", systemImage: "square.and.arrow.down")
                .frame(maxWidth: 280)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.blue)
        .controlSize(.large)
    }

    private func handleDrop(_ providers: [NSItemProvider]) async {
        for provider in providers {
            for type in ResumeFileType.supportedUTTypes {
                if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                    let url = await withCheckedContinuation { continuation in
                        _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                            continuation.resume(returning: url.map { URL(fileURLWithPath: $0.path) })
                        }
                    }
                    if let url { await viewModel.handlePickedURL(url) }
                    return
                }
            }
        }
    }
}

// MARK: - Review view

private struct ParsedReviewView: View {
    @Bindable var viewModel: ResumeParserViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Parsed Data").tag(0)
                Text("Raw Text").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                ParsedDataFormView(data: $viewModel.parsedData)
            } else {
                ExtractedTextView(text: viewModel.extractedText)
            }

            saveBar
        }
        .appScreenBackground()
    }

    private var saveBar: some View {
        VStack(spacing: 4) {
            Divider()
            HStack {
                Text("Review the data above, then save to your profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save to Profile") {
                    Task { await viewModel.saveToProfile(context: modelContext) }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.blue)
            }
            .padding()
        }
        .background(.bar)
    }
}

// MARK: - Parsed data form

private struct ParsedDataFormView: View {
    @Binding var data: ParsedResumeData

    var body: some View {
        Form {
            contactSection
            summarySection
            experienceSection
            educationSection
            skillsSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
    }

    private var contactSection: some View {
        Section("Contact") {
            LabeledContent("Name")   { TextField("Name", text: $data.name) }
            LabeledContent("Email")  { TextField("Email", text: $data.email) }
            LabeledContent("Phone")  { TextField("Phone", text: $data.phone) }
            LabeledContent("LinkedIn") { TextField("URL", text: $data.linkedIn) }
            LabeledContent("GitHub") { TextField("URL", text: $data.github) }
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            TextEditor(text: $data.summary)
                .frame(minHeight: 80)
        }
    }

    private var experienceSection: some View {
        Section("Experience (\(data.experiences.count) found)") {
            ForEach($data.experiences) { $exp in
                ExperienceRowView(experience: $exp)
            }
        }
    }

    private var educationSection: some View {
        Section("Education (\(data.education.count) found)") {
            ForEach($data.education) { $edu in
                EducationRowView(education: $edu)
            }
        }
    }

    private var skillsSection: some View {
        Section("Skills (\(data.skills.count) found)") {
            Text(data.skills.joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Experience row

private struct ExperienceRowView: View {
    @Binding var experience: ParsedExperience

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Job Title", text: $experience.title)
                    .font(.headline)
                if experience.confidence.needsReview {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .help(experience.confidence.label)
                }
            }
            TextField("Company", text: $experience.company)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !experience.bulletPoints.isEmpty {
                Text("\(experience.bulletPoints.count) bullet point(s)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Education row

private struct EducationRowView: View {
    @Binding var education: ParsedEducation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Institution", text: $education.institution)
                .font(.headline)
            TextField("Degree", text: $education.degree)
                .font(.subheadline)
            TextField("Field of Study", text: $education.field)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Raw text view

private struct ExtractedTextView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.text.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Saved confirmation

private struct SavedConfirmationView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.white)
            Text("Saved!")
                .font(AppTheme.heroTitle)
                .foregroundStyle(.white)
            Text("Your resume data has been saved to your profile.\nYou can edit it further in the Profile tab.")
                .font(AppTheme.body)
                .foregroundStyle(.white.opacity(0.84))
                .multilineTextAlignment(.center)
            Button("Import Another", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
    }
}
