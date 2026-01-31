//
//  AccountProfileView.swift
//  gym app
//
//  Account and profile management view accessible from Settings
//

import SwiftUI

struct AccountProfileView: View {
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var dataRepository = DataRepository.shared
    @Environment(\.dismiss) private var dismiss

    // Profile fields
    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var isPublic: Bool = false

    // Validation state
    @State private var usernameError: String?
    @State private var isCheckingUsername: Bool = false
    @State private var isUsernameAvailable: Bool?
    @State private var usernameCheckTask: Task<Void, Never>?

    // UI state
    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingSignIn: Bool = false
    @State private var showingDeleteConfirmation: Bool = false
    @State private var hasUnsavedChanges: Bool = false

    private var profileRepo: ProfileRepository {
        dataRepository.profileRepo
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Account Status Section
                accountStatusSection

                if authService.isAuthenticated {
                    // Profile Fields Section
                    profileFieldsSection

                    // Privacy Section
                    privacySection

                    // Save Button
                    if hasUnsavedChanges {
                        saveButton
                    }

                    // Danger Zone
                    dangerZoneSection
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentProfile()
        }
        .onChange(of: username) { _, _ in checkForChanges() }
        .onChange(of: displayName) { _, _ in checkForChanges() }
        .onChange(of: bio) { _, _ in checkForChanges() }
        .onChange(of: isPublic) { _, _ in checkForChanges() }
        .sheet(isPresented: $showingSignIn) {
            SignInView()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    try? await authService.deleteAccount()
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete your account and all cloud data. Local data will remain on this device. This cannot be undone.")
        }
    }

    // MARK: - Account Status Section

    private var accountStatusSection: some View {
        SettingsSection(title: "Account Status") {
            if authService.isAuthenticated {
                SettingsRow(icon: "person.circle.fill", title: "Signed In") {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let user = authService.currentUser {
                            Text(user.displayName ?? user.email ?? "Apple ID")
                                .subheadline(color: AppColors.textSecondary)
                        }
                        Text("via Apple")
                            .caption2(color: AppColors.textTertiary)
                    }
                }
            } else {
                SettingsRow(icon: "person.circle", title: "Not Signed In") {
                    Text("Local Only")
                        .subheadline(color: AppColors.textSecondary)
                }

                Button {
                    showingSignIn = true
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                            .frame(width: 28)
                        Text("Sign in with Apple")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .caption(color: AppColors.textTertiary)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.vertical, AppSpacing.sm)
            }
        }
    }

    // MARK: - Profile Fields Section

    private var profileFieldsSection: some View {
        SettingsSection(
            title: "Profile",
            footer: "Your username is unique and can contain letters, numbers, dots, underscores, and hyphens (1-32 characters)."
        ) {
            // Username field
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Username")
                    .caption(color: AppColors.textTertiary)

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
                        .caption(color: AppColors.error)
                }
            }
            .padding(.vertical, AppSpacing.sm)

            Divider()

            // Display Name field
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Display Name")
                    .caption(color: AppColors.textTertiary)

                TextField("Display Name (optional)", text: $displayName)
            }
            .padding(.vertical, AppSpacing.sm)

            Divider()

            // Bio field
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("Bio")
                        .caption(color: AppColors.textTertiary)
                    Spacer()
                    Text("\(bio.count)/160")
                        .caption(color: AppColors.textTertiary)
                }

                TextField("Short bio (optional)", text: $bio, axis: .vertical)
                    .lineLimit(3...5)
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > 160 {
                            bio = String(newValue.prefix(160))
                        }
                    }
            }
            .padding(.vertical, AppSpacing.sm)
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        SettingsSection(
            title: "Privacy",
            footer: "Public profiles can be discovered by other users. Friends can always see your profile."
        ) {
            Toggle("Public Profile", isOn: $isPublic)
                .padding(.vertical, AppSpacing.xs)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveProfile()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save Changes")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(canSave ? AppColors.dominant : AppColors.dominant.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(AppCorners.medium)
        }
        .disabled(!canSave || isSaving)
    }

    // MARK: - Danger Zone Section

    private var dangerZoneSection: some View {
        SettingsSection(title: "Account Actions") {
            Button(role: .destructive) {
                try? authService.signOut()
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(AppColors.error)
                        .frame(width: 28)
                    Text("Sign Out")
                        .foregroundColor(AppColors.error)
                    Spacer()
                }
            }
            .padding(.vertical, AppSpacing.sm)

            Divider()

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(AppColors.error)
                        .frame(width: 28)
                    Text("Delete Account")
                        .foregroundColor(AppColors.error)
                    Spacer()
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        // If username is empty, that's OK - user can save other fields
        if username.isEmpty {
            return hasUnsavedChanges && !isCheckingUsername
        }

        // If username is provided, it must be valid and available
        let validation = UsernameValidator.validate(username)
        let usernameOK = validation.isValid &&
            (isUsernameAvailable == true || username == profileRepo.currentProfile?.username)
        return usernameOK && !isCheckingUsername && hasUnsavedChanges
    }

    private func loadCurrentProfile() {
        if let profile = profileRepo.currentProfile {
            username = profile.username
            displayName = profile.displayName ?? ""
            bio = profile.bio ?? ""
            isPublic = profile.isPublic

            // If we already have a username, it's available (it's ours)
            if !profile.username.isEmpty {
                isUsernameAvailable = true
            }
        }
        hasUnsavedChanges = false
    }

    private func checkForChanges() {
        guard let profile = profileRepo.currentProfile else {
            hasUnsavedChanges = !username.isEmpty || !displayName.isEmpty || !bio.isEmpty
            return
        }

        hasUnsavedChanges =
            username != profile.username ||
            displayName != (profile.displayName ?? "") ||
            bio != (profile.bio ?? "") ||
            isPublic != profile.isPublic
    }

    private func validateUsername(_ value: String) {
        let normalized = UsernameValidator.normalize(value)

        // Empty username is allowed (optional field)
        if normalized.isEmpty {
            usernameError = nil
            isUsernameAvailable = nil
            return
        }

        // Reset state for non-empty username
        isUsernameAvailable = nil

        // Local validation first
        let validation = UsernameValidator.validate(normalized)
        if !validation.isValid {
            usernameError = validation.error?.localizedDescription
            return
        }

        usernameError = nil

        // Skip remote check if username unchanged
        if normalized == profileRepo.currentProfile?.username {
            isUsernameAvailable = true
            return
        }

        // Check availability remotely with debounce
        checkUsernameAvailability(normalized)
    }

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
                    // On network error, allow saving - worst case server rejects duplicate
                    isUsernameAvailable = true
                    usernameError = nil
                }
            }
        }
    }

    private func saveProfile() {
        isSaving = true

        Task {
            do {
                let normalized = UsernameValidator.normalize(username)

                // Handle username claiming/releasing (only if username is non-empty)
                // This is best-effort - profile saves even if username claim fails
                if !normalized.isEmpty {
                    do {
                        if let existingProfile = profileRepo.currentProfile,
                           !existingProfile.username.isEmpty,
                           existingProfile.username != normalized {
                            // Release old username and claim new one
                            try await FirestoreService.shared.releaseUsername(existingProfile.username)
                            try await FirestoreService.shared.claimUsername(normalized)
                        } else if profileRepo.currentProfile?.username.isEmpty != false {
                            // For new profiles or empty usernames, claim the username
                            try await FirestoreService.shared.claimUsername(normalized)
                        }
                    } catch {
                        // Username claiming failed (likely permissions) - continue with profile save
                        print("Username claim failed: \(error.localizedDescription)")
                    }
                }

                // Update or create profile (local save always succeeds)
                var profile: UserProfile
                if var existingProfile = profileRepo.currentProfile {
                    existingProfile.username = normalized
                    existingProfile.displayName = displayName.isEmpty ? nil : displayName
                    existingProfile.bio = bio.isEmpty ? nil : bio
                    existingProfile.isPublic = isPublic
                    existingProfile.updatedAt = Date()
                    existingProfile.syncStatus = .pendingSync
                    profileRepo.save(existingProfile)
                    profile = existingProfile
                } else {
                    var newProfile = profileRepo.createProfile(
                        username: normalized,
                        displayName: displayName.isEmpty ? nil : displayName
                    )
                    newProfile.bio = bio.isEmpty ? nil : bio
                    newProfile.isPublic = isPublic
                    profileRepo.save(newProfile)
                    profile = newProfile
                }

                // Try to sync to cloud (non-blocking - local save already done)
                do {
                    try await FirestoreService.shared.saveUserProfile(profile)
                } catch {
                    // Cloud sync failed but local save succeeded
                    print("Cloud profile sync failed: \(error.localizedDescription)")
                }

                await MainActor.run {
                    isSaving = false
                    hasUnsavedChanges = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountProfileView()
    }
}
