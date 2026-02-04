//
//  ProfilePhotoPickerSheet.swift
//  gym app
//
//  Photo selection and upload sheet for profile photos
//

import SwiftUI
import PhotosUI

struct ProfilePhotoPickerSheet: View {
    @ObservedObject var profileRepository: ProfileRepository
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var showingCamera = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                // Preview
                photoPreview
                    .padding(.top, AppSpacing.xl)

                // Actions
                actionButtons

                Spacer()

                // Upload/Save button
                if selectedImage != nil {
                    saveButton
                }
            }
            .padding(AppSpacing.screenPadding)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Photo Preview

    private var photoPreview: some View {
        ZStack {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(AppColors.dominant.opacity(0.3), lineWidth: 2)
                    }
            } else if let profile = profileRepository.currentProfile {
                ProfilePhotoView(
                    profile: profile,
                    size: 160,
                    borderWidth: 2
                )
            } else {
                Circle()
                    .fill(AppColors.dominant.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.dominant.opacity(0.5))
                    }
            }

            // Upload progress overlay
            if isUploading {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 160, height: 160)
                    .overlay {
                        VStack(spacing: AppSpacing.sm) {
                            ProgressView()
                                .tint(.white)
                            Text("\(Int(uploadProgress * 100))%")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.md) {
            // Photo Library Picker
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.body.weight(.medium))
                    Text("Choose from Library")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfaceSecondary)
                .cornerRadius(AppCorners.medium)
            }
            .buttonStyle(.plain)
            .onChange(of: selectedItem) { _, newValue in
                loadImage(from: newValue)
            }

            // Camera Button
            Button {
                showingCamera = true
            } label: {
                HStack {
                    Image(systemName: "camera")
                        .font(.body.weight(.medium))
                    Text("Take Photo")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfaceSecondary)
                .cornerRadius(AppCorners.medium)
            }
            .buttonStyle(.plain)

            // Remove Photo Button (if photo exists)
            if profileRepository.currentProfile?.profilePhotoURL != nil || selectedImage != nil {
                Button(role: .destructive) {
                    removePhoto()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(.body.weight(.medium))
                        Text("Remove Photo")
                    }
                    .foregroundColor(AppColors.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.error.opacity(0.1))
                    .cornerRadius(AppCorners.medium)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            uploadPhoto()
        } label: {
            HStack {
                if isUploading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                }
                Text(isUploading ? "Uploading..." : "Save Photo")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.dominant)
            .foregroundColor(.white)
            .cornerRadius(AppCorners.medium)
        }
        .disabled(isUploading)
        .padding(.bottom, AppSpacing.md)
    }

    // MARK: - Actions

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                }
            }
        }
    }

    private func uploadPhoto() {
        guard let image = selectedImage else { return }

        isUploading = true
        uploadProgress = 0

        Task {
            do {
                let downloadURL = try await ProfilePhotoService.shared.uploadProfilePhoto(image) { progress in
                    uploadProgress = progress
                }

                // Update profile with new photo URL
                if var profile = profileRepository.currentProfile {
                    profile.profilePhotoURL = downloadURL
                    profile.updatedAt = Date()
                    await MainActor.run {
                        profileRepository.save(profile)
                    }

                    // Sync to Firestore so other users see the photo
                    try await FirestoreService.shared.saveUserProfile(profile)
                }

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func removePhoto() {
        if selectedImage != nil {
            // Just clear the selected image
            selectedImage = nil
            return
        }

        // Remove from storage and profile
        Task {
            do {
                try await ProfilePhotoService.shared.deleteProfilePhoto()

                if var profile = profileRepository.currentProfile {
                    profile.profilePhotoURL = nil
                    profile.updatedAt = Date()
                    await MainActor.run {
                        profileRepository.save(profile)
                    }

                    // Sync to Firestore so other users see the photo removed
                    try await FirestoreService.shared.saveUserProfile(profile)
                }

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ProfilePhotoPickerSheet(profileRepository: ProfileRepository(persistence: .preview))
}
