//
//  ProfilePhotoService.swift
//  gym app
//
//  Firebase Storage service for profile photos
//

import Foundation
import FirebaseStorage
import UIKit

enum ProfilePhotoError: LocalizedError {
    case notAuthenticated
    case imageProcessingFailed
    case uploadFailed(String)
    case deletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to upload a profile photo"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .deletionFailed(let message):
            return "Failed to delete photo: \(message)"
        }
    }
}

@MainActor
class ProfilePhotoService: ObservableObject {
    static let shared = ProfilePhotoService()

    private let storage = Storage.storage()
    private let core = FirestoreCore.shared
    private let maxImageDimension: CGFloat = 400
    private let jpegQuality: CGFloat = 0.8
    private let storagePath = "profile-photos"

    private init() {}

    /// Upload a profile photo to Firebase Storage
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - progress: Optional callback for upload progress (0.0 to 1.0)
    /// - Returns: The download URL for the uploaded image
    func uploadProfilePhoto(_ image: UIImage, progress: ((Double) -> Void)? = nil) async throws -> String {
        guard let userId = core.userId else {
            throw ProfilePhotoError.notAuthenticated
        }

        guard let imageData = processImage(image) else {
            throw ProfilePhotoError.imageProcessingFailed
        }

        // Delete existing photo first (ignore errors)
        try? await deleteProfilePhoto()

        let storageRef = storage.reference().child("\(storagePath)/\(userId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putData(imageData, metadata: metadata)

            uploadTask.observe(.progress) { snapshot in
                if let totalBytes = snapshot.progress?.totalUnitCount,
                   let completedBytes = snapshot.progress?.completedUnitCount,
                   totalBytes > 0 {
                    let uploadProgress = Double(completedBytes) / Double(totalBytes)
                    Task { @MainActor in
                        progress?(uploadProgress)
                    }
                }
            }

            uploadTask.observe(.success) { _ in
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: ProfilePhotoError.uploadFailed(error.localizedDescription))
                    } else if let url = url {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: ProfilePhotoError.uploadFailed("No download URL returned"))
                    }
                }
            }

            uploadTask.observe(.failure) { snapshot in
                let errorMessage = snapshot.error?.localizedDescription ?? "Unknown error"
                continuation.resume(throwing: ProfilePhotoError.uploadFailed(errorMessage))
            }
        }
    }

    /// Delete the current user's profile photo from Firebase Storage
    /// Returns silently if photo doesn't exist or deletion fails
    func deleteProfilePhoto() async throws {
        guard let userId = core.userId else {
            throw ProfilePhotoError.notAuthenticated
        }

        let storageRef = storage.reference().child("\(storagePath)/\(userId).jpg")

        do {
            try await storageRef.delete()
        } catch let error as NSError {
            // Ignore "object not found" errors (photo may not exist)
            // StorageErrorCode.objectNotFound = -13010
            if error.code == StorageErrorCode.objectNotFound.rawValue {
                return
            }
            // Also ignore permission errors during delete - we'll overwrite anyway
            if error.code == StorageErrorCode.unauthorized.rawValue {
                return
            }
            throw ProfilePhotoError.deletionFailed(error.localizedDescription)
        }
    }

    /// Process image: resize and compress
    private func processImage(_ image: UIImage) -> Data? {
        let resizedImage = resizeImage(image, maxDimension: maxImageDimension)
        return resizedImage.jpegData(compressionQuality: jpegQuality)
    }

    /// Resize image to fit within max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let originalSize = image.size

        // If already smaller than max, return original
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let widthRatio = maxDimension / originalSize.width
        let heightRatio = maxDimension / originalSize.height
        let ratio = min(widthRatio, heightRatio)

        let newSize = CGSize(
            width: originalSize.width * ratio,
            height: originalSize.height * ratio
        )

        // Render resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
