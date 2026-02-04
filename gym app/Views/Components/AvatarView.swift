//
//  AvatarView.swift
//  gym app
//
//  Reusable avatar component for user profiles
//
//  DEPRECATED: Use ProfilePhotoView instead for photo support
//

import SwiftUI

@available(*, deprecated, message: "Use ProfilePhotoView instead for photo support")
struct AvatarView: View {
    let profile: UserProfile
    var size: CGFloat = 48
    var color: Color = AppColors.dominant
    var characterCount: Int = 2

    var body: some View {
        Circle()
            .fill(color.opacity(0.2))
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(scaledFont)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
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
        default: return .headline
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AvatarView(profile: UserProfile(username: "johndoe"), size: 28, characterCount: 1)
        AvatarView(profile: UserProfile(username: "johndoe"), size: 44)
        AvatarView(profile: UserProfile(username: "johndoe"), size: 52)
    }
}
