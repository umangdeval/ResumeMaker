import SwiftData
import SwiftUI

@Observable
@MainActor
final class ProfileViewModel {
    private(set) var profile: UserProfile?

    var isAddingExperience = false
    var isAddingEducation = false
    var editingExperience: Experience?
    var editingEducation: Education?
    var newSkill = ""

    func load(context: ModelContext) {
        guard profile == nil else { return }
        let descriptor = FetchDescriptor<UserProfile>()
        let results = (try? context.fetch(descriptor)) ?? []
        if let existing = results.first {
            profile = existing
        } else {
            let fresh = UserProfile()
            context.insert(fresh)
            profile = fresh
            try? context.save()
        }
    }

    func save(context: ModelContext) {
        profile?.updatedAt = .now
        try? context.save()
    }

    func addExperience(_ experience: Experience, context: ModelContext) {
        guard let profile else { return }
        context.insert(experience)
        profile.experiences.append(experience)
        save(context: context)
    }

    func deleteExperience(_ experience: Experience, context: ModelContext) {
        guard let profile else { return }
        profile.experiences.removeAll { $0.id == experience.id }
        context.delete(experience)
        save(context: context)
    }

    func addEducation(_ education: Education, context: ModelContext) {
        guard let profile else { return }
        context.insert(education)
        profile.education.append(education)
        save(context: context)
    }

    func deleteEducation(_ education: Education, context: ModelContext) {
        guard let profile else { return }
        profile.education.removeAll { $0.id == education.id }
        context.delete(education)
        save(context: context)
    }

    func addSkill(context: ModelContext) {
        let trimmed = newSkill.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, profile?.skills.contains(trimmed) == false else { return }
        profile?.skills.append(trimmed)
        newSkill = ""
        save(context: context)
    }

    func removeSkill(_ skill: String, context: ModelContext) {
        profile?.skills.removeAll { $0 == skill }
        save(context: context)
    }
}
