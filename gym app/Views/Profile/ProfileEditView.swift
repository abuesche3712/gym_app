//
//  ProfileEditView.swift
//  gym app
//
//  View for editing user profile settings
//

import SwiftUI

struct ProfileEditView: View {
    @ObservedObject var profileRepository: ProfileRepository
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var isPublic: Bool = false

    @State private var usernameError: String?
    @State private var isCheckingUsername: Bool = false
    @State private var isUsernameAvailable: Bool?
    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private let isNewProfile: Bool

    init(profileRepository: ProfileRepository, isNewProfile: Bool = false) {
        self.profileRepository = profileRepository
        self.isNewProfile = isNewProfile
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            TextField("username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: username) { _, newValue in
                                    validateUsername(newValue)
                                }

                            if isCheckingUsername {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let available = isUsernameAvailable {
                                Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(available ? .green : .red)
                            }
                        }

                        if let error = usernameError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Identity")
                } footer: {
                    Text("Usernames are unique and can contain letters, numbers, dots, underscores, and hyphens (1-32 characters).")
                }

                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Display Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Display Name (optional)", text: $displayName)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack {
                            Text("Bio")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(bio.count)/160")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        TextField("Short bio (optional)", text: $bio, axis: .vertical)
                            .lineLimit(3...5)
                            .onChange(of: bio) { _, newValue in
                                if newValue.count > 160 {
                                    bio = String(newValue.prefix(160))
                                }
                            }
                    }
                } header: {
                    Text("About You")
                }

                Section {
                    Toggle("Public Profile", isOn: $isPublic)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Public profiles can be discovered by other users. Friends can always see your profile.")
                }
            }
            .navigationTitle(isNewProfile ? "Set Up Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isNewProfile {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNewProfile ? "Create" : "Save") {
                        saveProfile()
                    }
                    .disabled(!canSave)
                    .opacity(isSaving ? 0 : 1)
                    .overlay {
                        if isSaving {
                            ProgressView()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isNewProfile)
            .onAppear {
                loadCurrentProfile()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var canSave: Bool {
        let validation = UsernameValidator.validate(username)
        return validation.isValid &&
               (isUsernameAvailable == true || username == profileRepository.currentProfile?.username) &&
               !isSaving &&
               !isCheckingUsername
    }

    private func loadCurrentProfile() {
        if let profile = profileRepository.currentProfile {
            username = profile.username
            displayName = profile.displayName ?? ""
            bio = profile.bio ?? ""
            isPublic = profile.isPublic

            // If we already have a username, it's available (it's ours)
            if !profile.username.isEmpty {
                isUsernameAvailable = true
            }
        }
    }

    private func validateUsername(_ value: String) {
        let normalized = UsernameValidator.normalize(value)

        // Reset state
        isUsernameAvailable = nil

        // Local validation first
        let validation = UsernameValidator.validate(normalized)
        if !validation.isValid {
            usernameError = validation.error?.localizedDescription
            return
        }

        usernameError = nil

        // Skip remote check if username unchanged
        if normalized == profileRepository.currentProfile?.username {
            isUsernameAvailable = true
            return
        }

        // Check availability remotely with debounce
        checkUsernameAvailability(normalized)
    }

    @State private var usernameCheckTask: Task<Void, Never>?

    private func checkUsernameAvailability(_ username: String) {
        usernameCheckTask?.cancel()

        usernameCheckTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            guard !Task.isCancelled else { return }

            await MainActor.run {
                isCheckingUsername = true
            }

            do {
                let available = try await FirestoreService.shared.isUsernameAvailable(username)
                await MainActor.run {
                    isUsernameAvailable = available
                    if !available {
                        usernameError = "This username is already taken"
                    }
                    isCheckingUsername = false
                }
            } catch {
                await MainActor.run {
                    isCheckingUsername = false
                }
            }
        }
    }

    private func saveProfile() {
        isSaving = true

        Task {
            do {
                let normalized = UsernameValidator.normalize(username)

                // If username changed, handle username claiming
                if let existingProfile = profileRepository.currentProfile,
                   !existingProfile.username.isEmpty,
                   existingProfile.username != normalized {
                    // Release old username and claim new one
                    try await FirestoreService.shared.releaseUsername(existingProfile.username)
                    try await FirestoreService.shared.claimUsername(normalized)
                }

                // For new profiles, claim the username
                if isNewProfile || profileRepository.currentProfile?.username.isEmpty == true {
                    try await FirestoreService.shared.claimUsername(normalized)
                }

                // Update or create profile
                if var profile = profileRepository.currentProfile {
                    profile.username = normalized
                    profile.displayName = displayName.isEmpty ? nil : displayName
                    profile.bio = bio.isEmpty ? nil : bio
                    profile.isPublic = isPublic
                    profileRepository.save(profile)

                    // Sync to cloud
                    try await FirestoreService.shared.saveUserProfile(profile)
                } else {
                    let profile = profileRepository.createProfile(
                        username: normalized,
                        displayName: displayName.isEmpty ? nil : displayName
                    )
                    var updatedProfile = profile
                    updatedProfile.bio = bio.isEmpty ? nil : bio
                    updatedProfile.isPublic = isPublic
                    profileRepository.save(updatedProfile)

                    // Sync to cloud
                    try await FirestoreService.shared.saveUserProfile(updatedProfile)
                }

                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    ProfileEditView(
        profileRepository: ProfileRepository(persistence: .preview),
        isNewProfile: true
    )
}
