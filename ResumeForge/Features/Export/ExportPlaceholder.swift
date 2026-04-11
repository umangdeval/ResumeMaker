import AppKit
import SwiftData
import SwiftUI

struct ExportView: View {
	@Query(sort: \GeneratedResume.createdAt, order: .reverse) private var resumes: [GeneratedResume]
	@State private var viewModel = ExportViewModel()
	@State private var selectedResume: GeneratedResume?

	var body: some View {
		List(resumes, selection: $selectedResume) { resume in
			Button(resume.displayTitle) {
				selectedResume = resume
			}
			.buttonStyle(.plain)
		}
		.safeAreaInset(edge: .bottom) {
			if let resume = selectedResume {
				VStack(spacing: 12) {
					Picker("Format", selection: $viewModel.selectedFormat) {
						ForEach(ResumeFormat.allCases, id: \.self) { format in
							Text(format.displayName).tag(format)
						}
					}
					.pickerStyle(.segmented)

					Button("Export") {
						viewModel.export(resume: resume)
					}
					.buttonStyle(.borderedProminent)
					.tint(AppTheme.blue)
				}
				.padding()
				.background(.regularMaterial)
			}
		}
		.sheet(isPresented: $viewModel.showShareSheet) {
			ExportShareSheet(url: viewModel.exportedURL)
				.frame(minWidth: 440, minHeight: 180)
		}
		.alert("Export Error", isPresented: .constant(viewModel.error != nil)) {
			Button("OK") { viewModel.error = nil }
		} message: {
			Text(viewModel.error ?? "Something went wrong.")
		}
		.navigationTitle("Export")
	}
}

private struct ExportShareSheet: View {
	let url: URL?
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading, spacing: 12) {
				if let url {
					Text("Exported file is ready.")
						.font(AppTheme.sectionTitle)
						.foregroundStyle(AppTheme.text)
					Text(url.path)
						.font(.caption.monospaced())
						.textSelection(.enabled)
						.foregroundStyle(AppTheme.textSecondary)

					HStack {
						ShareLink(item: url) {
							Label("Share", systemImage: "square.and.arrow.up")
						}
						.buttonStyle(.borderedProminent)
						.tint(AppTheme.blue)

						Button("Reveal in Finder") {
							NSWorkspace.shared.activateFileViewerSelecting([url])
						}
						.buttonStyle(.bordered)
					}
				} else {
					Text("No exported file was found.")
						.foregroundStyle(AppTheme.textSecondary)
				}
				Spacer(minLength: 0)
			}
			.padding()
			.navigationTitle("Export")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Done") { dismiss() }
				}
			}
		}
	}
}

#Preview {
	NavigationStack {
		ExportView()
	}
}
