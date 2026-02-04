//
//  ProfilePhotoView.swift
//  gym app
//
//  Reusable avatar component with photo support
//

import SwiftUI

struct ProfilePhotoView: View {
    let profile: UserProfile
    var size: CGFloat = 48
    var backgroundColor: Color = AppColors.dominant.opacity(0.2)
    var foregroundColor: Color = AppColors.dominant
    var borderColor: Color = AppColors.dominant.opacity(0.3)
    var borderWidth: CGFloat = 1.5
    var characterCount: Int = 2

    var body: some View {
        Group {
            if let photoURL = profile.profilePhotoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        loadingView
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(borderColor, lineWidth: borderWidth)
        }
    }

    private var loadingView: some View {
        Circle()
            .fill(backgroundColor)
            .overlay {
                ProgressView()
                    .scaleEffect(size < 40 ? 0.6 : 0.8)
            }
    }

    private var initialsView: some View {
        Circle()
            .fill(backgroundColor)
            .overlay {
                Text(initials)
                    .font(scaledFont)
                    .fontWeight(.semibold)
                    .foregroundColor(foregroundColor)
            }
    }

    private var initials: String {
        let name = profile.displayName?.isEmpty == false ? profile.displayName! : profile.username
        return String(name.prefix(characterCount)).uppercased()
    }

    private var scaledFont: Font {
        switch size {
        case ...28: return .caption2
        case ...36: return .caption
        case ...44: return .subheadline
        case ...56: return .headline
        default: return .title3
        }
    }

    // MARK: - Convenience Variants

    /// Gold accent variant for social header
    static func gold(profile: UserProfile, size: CGFloat = 32) -> ProfilePhotoView {
        ProfilePhotoView(
            profile: profile,
            size: size,
            backgroundColor: AppColors.accent2.opacity(0.2),
            foregroundColor: AppColors.accent2,
            borderColor: AppColors.accent2.opacity(0.3)
        )
    }

    /// Muted variant for secondary contexts (e.g., friends list)
    static func muted(profile: UserProfile, size: CGFloat = 44) -> ProfilePhotoView {
        ProfilePhotoView(
            profile: profile,
            size: size,
            backgroundColor: AppColors.textTertiary.opacity(0.2),
            foregroundColor: AppColors.textTertiary,
            borderColor: AppColors.textTertiary.opacity(0.2)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfilePhotoView(profile: UserProfile(username: "johndoe"), size: 28, characterCount: 1)
        ProfilePhotoView(profile: UserProfile(username: "johndoe"), size: 44)
        ProfilePhotoView(profile: UserProfile(username: "johndoe", displayName: "John Doe"), size: 64)
        ProfilePhotoView.gold(profile: UserProfile(username: "johndoe"), size: 32)
        ProfilePhotoView.muted(profile: UserProfile(username: "johndoe"), size: 44)
    }
    .padding()
    .background(AppColors.background)
}
