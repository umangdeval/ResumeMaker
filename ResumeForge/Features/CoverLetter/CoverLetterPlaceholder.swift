import SwiftData
import SwiftUI

struct CoverLetterView: View {
	@Environment(\.modelContext) private var context
	@Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
	@Query(sort: \JobDescription.updatedAt, order: .reverse) private var jobs: [JobDescription]
	@Query(sort: \StylePersona.createdAt, order: .reverse) private var personas: [StylePersona]
	@State private var viewModel = CoverLetterViewModel()

	var body: some View {
		Group {
			if let profile = profiles.first, let job = jobs.first {
				content(profile: profile, job: job)
			} else {
				ContentUnavailableView(
					"Cover Letter Requires Data",
					systemImage: "doc.text",
					description: Text("Add at least one profile and one job description first.")
				)
			}
		}
		.navigationTitle("Cover Letter")
		.alert("Cover Letter Error", isPresented: .constant(viewModel.error != nil)) {
			Button("OK") { viewModel.error = nil }
		} message: {
			Text(viewModel.error ?? "Something went wrong.")
		}
	}

	@ViewBuilder
	private func content(profile: UserProfile, job: JobDescription) -> some View {
		VStack(spacing: 0) {
			if viewModel.isGenerating {
				ScrollView {
					Text(viewModel.streamBuffer)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding()
						.textSelection(.enabled)
				}
				.background(AppTheme.surface)
				.safeAreaInset(edge: .bottom) {
					HStack {
						ProgressView("Generating…")
						Spacer()
					}
					.padding()
					.background(.bar)
				}
			} else if !viewModel.generatedText.isEmpty {
				TextEditor(text: $viewModel.generatedText)
					.font(.body)
					.padding(8)
					.background(AppTheme.surface)
					.safeAreaInset(edge: .bottom) {
						HStack {
							Button("Regenerate") {
								generate(profile: profile, job: job)
							}
							.buttonStyle(.bordered)

							Spacer()

							Button("Save") {
								viewModel.save(job: job, context: context)
							}
							.buttonStyle(.borderedProminent)
							.tint(AppTheme.blue)
						}
						.padding()
						.background(.bar)
					}
			} else {
				VStack(spacing: 14) {
					Text("Generate a tailored, fact-grounded cover letter.")
						.font(AppTheme.body)
						.foregroundStyle(AppTheme.textSecondary)
					Button("Generate Cover Letter") {
						generate(profile: profile, job: job)
					}
					.buttonStyle(.borderedProminent)
					.tint(AppTheme.blue)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.padding()
			}
		}
		.appScreenBackground()
	}

	private func generate(profile: UserProfile, job: JobDescription) {
		guard let service = viewModel.makePreferredService() else {
			viewModel.error = CoverLetterViewModel.CoverLetterError.noConfiguredProvider.localizedDescription
			return
		}
		let styleTraits = personas.first?.derivedTraits ?? "Professional, concise, and specific tone."
		Task {
			await viewModel.generate(
				profile: profile,
				job: job,
				styleTraits: styleTraits,
				service: service,
				context: context
			)
		}
	}
}

#Preview {
	NavigationStack {
		CoverLetterView()
	}
}
