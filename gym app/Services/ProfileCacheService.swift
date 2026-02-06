//
//  ProfileCacheService.swift
//  gym app
//
//  Shared profile cache to avoid duplicate fetches across ViewModels
//

import Foundation

private struct CachedProfile {
    let profile: UserProfile
    let fetchedAt: Date
}

@MainActor
class ProfileCacheService {
    static let shared = ProfileCacheService()
    private var cache: [String: CachedProfile] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 minutes

    private let firestoreService = FirestoreService.shared

    private init() {}

    /// Fetch a profile for a userId, using cache when available
    func profile(for userId: String) async -> UserProfile {
        // Check cache (and TTL)
        if let cached = cache[userId],
           Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.profile
        }

        // Try fetching from Firestore
        if let fetched = try? await firestoreService.fetchPublicProfile(userId: userId) {
            cache[userId] = CachedProfile(profile: fetched, fetchedAt: Date())
            return fetched
        }

        // Fallback for unknown users
        return UserProfile(id: UUID(), username: "unknown", displayName: "Unknown User")
    }

    /// Prefetch profiles for multiple userIds in parallel
    func prefetch(userIds: [String]) async {
        let uncached = userIds.filter { userId in
            guard let cached = cache[userId] else { return true }
            return Date().timeIntervalSince(cached.fetchedAt) >= cacheTTL
        }

        guard !uncached.isEmpty else { return }

        await withTaskGroup(of: (String, UserProfile?).self) { group in
            for userId in uncached {
                group.addTask {
                    let profile = try? await self.firestoreService.fetchPublicProfile(userId: userId)
                    return (userId, profile)
                }
            }

            for await (userId, profile) in group {
                if let profile {
                    cache[userId] = CachedProfile(profile: profile, fetchedAt: Date())
                }
            }
        }
    }

    /// Update the cache with a known profile (e.g., after creating/editing)
    func updateCache(userId: String, profile: UserProfile) {
        cache[userId] = CachedProfile(profile: profile, fetchedAt: Date())
    }

    /// Clear all cached profiles
    func clearCache() {
        cache.removeAll()
    }
}
