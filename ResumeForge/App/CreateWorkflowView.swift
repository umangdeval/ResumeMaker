import SwiftData
import SwiftUI

struct CreateWorkflowView: View {
    @Environment(Router.self) private var router
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query(sort: \JobDescription.updatedAt, order: .reverse) private var jobs: [JobDescription]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                stepCard(title: "Step 1", name: "Import / Parse Resume", subtitle: "Extract and normalize your resume data.", icon: "doc.text.viewfinder") {
                    ResumeParserView()
                }
                stepCard(title: "Step 2", name: "Add Job Description", subtitle: "Define the exact role you are targeting.", icon: "doc.plaintext") {
                    JobDescriptionView()
                }

                if let profile = profiles.first, let job = jobs.first {
                    stepCard(title: "Step 3", name: "AI Council", subtitle: "Run parallel model analysis and synthesis.", icon: "person.3.sequence") {
                        AICouncilView(profile: profile, jobDescription: job) {
                            router.push(.resumeBuilder)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Step 3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("AI Council")
                            .font(AppTheme.sectionTitle)
                            .foregroundStyle(AppTheme.text)
                        Text("Complete Step 1 and Step 2 first. AI Council requires a saved profile and job description.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .appCard()
                }
            }
            .padding(20)
            .appContentWidth()
        }
        .background(AppTheme.bg)
        .navigationTitle("Create")
    }

    private func stepCard<Destination: View>(title: String, name: String, subtitle: String, icon: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(AppTheme.blue)
                    Text(name)
                        .font(AppTheme.sectionTitle)
                        .foregroundStyle(AppTheme.text)
                }
                Text(subtitle)
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

#Preview {
    NavigationStack {
        CreateWorkflowView()
    }
}
