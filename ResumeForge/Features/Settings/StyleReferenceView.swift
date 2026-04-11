import SwiftData
import SwiftUI

struct StyleReferenceView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = StylePersonaViewModel()

    var body: some View {
        Form {
            Section("Paste a cover letter you liked") {
                TextEditor(text: $viewModel.sampleText)
                    .frame(minHeight: 200)
            }

            Section {
                Button(viewModel.isAnalysing ? "Analysing…" : "Analyse My Style") {
                    guard let service = viewModel.makePreferredService() else {
                        viewModel.error = StylePersonaViewModel.StylePersonaError.noConfiguredProvider.localizedDescription
                        return
                    }
                    Task {
                        await viewModel.analyseStyle(service: service, context: context)
                    }
                }
                .disabled(viewModel.sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAnalysing)
            }

            if !viewModel.derivedTraits.isEmpty {
                Section("Your Style Traits") {
                    Text(viewModel.derivedTraits)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Writing Style Reference")
        .onAppear { viewModel.load(context: context) }
        .alert("Style Analysis Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "Something went wrong.")
        }
    }
}

#Preview {
    NavigationStack {
        StyleReferenceView()
    }
}
