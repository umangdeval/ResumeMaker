import SwiftUI
import SwiftData

@Observable
@MainActor
final class ProfileViewModel {
    var isSaving = false
    var savedToast = false
    var error: Error?

    func save(profile: UserProfile, context: ModelContext) {
        isSaving = true
        profile.updatedAt = .now
        do {
            try context.save()
            isSaving = false
            savedToast = true
        } catch {
            self.error = error
            isSaving = false
        }
    }

    func addExperience(to profile: UserProfile, context: ModelContext) {
        let exp = Experience(company: "", title: "", startDate: .now)
        context.insert(exp)
        profile.experiences.append(exp)
    }

    func deleteExperiences(at offsets: IndexSet, from profile: UserProfile, context: ModelContext) {
        for index in offsets {
            let exp = profile.experiences[index]
            profile.experiences.remove(at: index)
            context.delete(exp)
        }
        try? context.save()
    }

    func addEducation(to profile: UserProfile, context: ModelContext) {
        let edu = Education(institution: "", degree: "", field: "", graduationDate: .now)
        context.insert(edu)
        profile.education.append(edu)
    }

    func deleteEducation(at offsets: IndexSet, from profile: UserProfile, context: ModelContext) {
        for index in offsets {
            let edu = profile.education[index]
            profile.education.remove(at: index)
            context.delete(edu)
        }
        try? context.save()
    }
}
