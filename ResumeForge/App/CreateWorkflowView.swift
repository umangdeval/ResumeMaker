import SwiftData
import SwiftUI

struct CreateWorkflowView: View {
    @Environment(Router.self) private var router
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query(sort: \JobDescription.updatedAt, order: .reverse) private var jobs: [JobDescription]

    var body: some View {
        List {
            Section("Step 1") {
                NavigationLink {
                    ResumeParserView()
                } label: {
                    Label("Import / Parse Resume", systemImage: "doc.text.viewfinder")
                }
            }

            Section("Step 2") {
                NavigationLink {
                    JobDescriptionView()
                } label: {
                    Label("Add Job Description", systemImage: "doc.plaintext")
                }
            }

            Section("Step 3") {
                if let profile = profiles.first, let job = jobs.first {
                    NavigationLink {
                        AICouncilView(profile: profile, jobDescription: job) {
                            router.push(.resumeBuilder)
                        }
                    } label: {
                        Label("AI Council", systemImage: "person.3.sequence")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AI Council")
                            .font(.headline)
                        Text("Complete Step 1 and Step 2 first. AI Council requires a saved profile and job description.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Create")
    }
}

#Preview {
    NavigationStack {
        CreateWorkflowView()
    }
}
