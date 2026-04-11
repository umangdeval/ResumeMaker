import SwiftData
import SwiftUI

struct ResumeBuilderView: View {
	@Environment(\.modelContext) private var context
	@Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
	@Query(sort: \JobDescription.updatedAt, order: .reverse) private var jobs: [JobDescription]
	@State private var viewModel = ResumeBuilderViewModel()
	@State private var selectedFormat: ResumeFormat = ResumeBuilderViewModel.preferredOutputFormatFromLastImport()
	@State private var councilSynthesis: String = ""

	var body: some View {
		Group {
			if let profile = profiles.first, let job = jobs.first {
				content(profile: profile, job: job)
			} else {
				ContentUnavailableView(
					"Resume Builder Requires Data",
					systemImage: "doc.text",
					description: Text("Add at least one profile and one job description first.")
				)
			}
		}
		.navigationTitle("Resume Builder")
		.alert("Resume Builder Error", isPresented: .constant(viewModel.error != nil)) {
			Button("OK") { viewModel.error = nil }
		} message: {
			Text(viewModel.error ?? "Something went wrong.")
		}
	}

	@ViewBuilder
	private func content(profile: UserProfile, job: JobDescription) -> some View {
		VStack(spacing: 0) {
			if viewModel.isGenerating {
				ProgressView("Building ATS-optimized resume…")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				TextEditor(text: $viewModel.editedContent)
					.font(.system(.body, design: .monospaced))
					.padding(8)
					.background(AppTheme.surface)
			}
		}
		.safeAreaInset(edge: .bottom) {
			VStack(spacing: 10) {
				TextField("Paste AI Council synthesis (optional)", text: $councilSynthesis, axis: .vertical)
					.lineLimit(2...4)
					.textFieldStyle(.roundedBorder)

				HStack {
					Picker("Format", selection: $selectedFormat) {
						ForEach(ResumeFormat.allCases, id: \.self) { format in
							Text(format.displayName).tag(format)
						}
					}
					.pickerStyle(.segmented)

					Button("Generate") {
						generate(profile: profile, job: job)
					}
					.buttonStyle(.borderedProminent)
					.tint(AppTheme.blue)

					Button("Save") {
						viewModel.save(
							job: job,
							format: selectedFormat,
							councilSynthesis: councilSynthesis,
							context: context
						)
					}
					.buttonStyle(.bordered)
					.disabled(viewModel.editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
				}
			}
			.padding()
			.background(.bar)
		}
	}

	private func generate(profile: UserProfile, job: JobDescription) {
		guard let service = viewModel.makePreferredService() else {
			viewModel.error = ResumeBuilderViewModel.ResumeBuilderError.noConfiguredProvider.localizedDescription
			return
		}

		Task {
			await viewModel.generate(
				profile: profile,
				job: job,
				councilSynthesis: councilSynthesis,
				outputFormat: selectedFormat,
				service: service
			)
		}
	}
}

#Preview {
	NavigationStack {
		ResumeBuilderView()
	}
}
