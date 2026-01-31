//
//  ProfileRepository.swift
//  gym app
//
//  Handles UserProfile CRUD operations and CoreData conversion
//

import CoreData
import Combine

@MainActor
class ProfileRepository: ObservableObject {
    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    @Published private(set) var currentProfile: UserProfile?

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        loadCurrentProfile()
    }

    // MARK: - CRUD Operations

    /// Load the current user's profile (there should only be one)
    func loadCurrentProfile() {
        let request = NSFetchRequest<UserProfileEntity>(entityName: "UserProfileEntity")
        request.fetchLimit = 1

        do {
            if let entity = try viewContext.fetch(request).first {
                currentProfile = entity.toModel()
            }
        } catch {
            Logger.error(error, context: "ProfileRepository.loadCurrentProfile")
        }
    }

    /// Save or update the user profile
    func save(_ profile: UserProfile) {
        var profileToSave = profile
        profileToSave.updatedAt = Date()
        profileToSave.syncStatus = .pendingSync

        let entity = findOrCreateEntity(id: profile.id)
        entity.update(from: profileToSave)
        persistence.save()

        currentProfile = profileToSave
    }

    /// Create a new profile (called when user first sets up their account)
    func createProfile(username: String, displayName: String? = nil) -> UserProfile {
        let profile = UserProfile(
            id: UUID(),
            username: UsernameValidator.normalize(username),
            displayName: displayName,
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pendingSync
        )

        save(profile)
        return profile
    }

    /// Delete the current profile (for account deletion)
    func deleteProfile() {
        guard let profile = currentProfile else { return }
        if let entity = findEntity(id: profile.id) {
            viewContext.delete(entity)
            persistence.save()
        }
        currentProfile = nil
    }

    /// Update specific profile fields
    func updateProfile(
        displayName: String? = nil,
        bio: String? = nil,
        isPublic: Bool? = nil,
        weightUnit: WeightUnit? = nil,
        distanceUnit: DistanceUnit? = nil,
        defaultRestTime: Int? = nil
    ) {
        guard var profile = currentProfile else { return }

        if let displayName = displayName {
            profile.displayName = displayName.isEmpty ? nil : displayName
        }
        if let bio = bio {
            // Enforce 160 char limit
            profile.bio = bio.isEmpty ? nil : String(bio.prefix(160))
        }
        if let isPublic = isPublic {
            profile.isPublic = isPublic
        }
        if let weightUnit = weightUnit {
            profile.weightUnit = weightUnit
        }
        if let distanceUnit = distanceUnit {
            profile.distanceUnit = distanceUnit
        }
        if let defaultRestTime = defaultRestTime {
            profile.defaultRestTime = defaultRestTime
        }

        save(profile)
    }

    // MARK: - Entity Operations (for sync)

    func findEntity(id: UUID) -> UserProfileEntity? {
        let request = NSFetchRequest<UserProfileEntity>(entityName: "UserProfileEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    func updateFromCloud(_ cloudProfile: UserProfile) {
        // Only update if cloud is newer
        guard let local = currentProfile else {
            // No local profile, save cloud version
            let entity = findOrCreateEntity(id: cloudProfile.id)
            entity.update(from: cloudProfile)
            persistence.save()
            currentProfile = cloudProfile
            return
        }

        if cloudProfile.updatedAt > local.updatedAt {
            let entity = findOrCreateEntity(id: cloudProfile.id)
            var merged = cloudProfile
            merged.syncStatus = .synced
            entity.update(from: merged)
            persistence.save()
            currentProfile = merged
        }
    }

    // MARK: - Private Helpers

    private func findOrCreateEntity(id: UUID) -> UserProfileEntity {
        if let existing = findEntity(id: id) {
            return existing
        }
        let entity = UserProfileEntity(context: viewContext)
        entity.id = id
        return entity
    }
}
