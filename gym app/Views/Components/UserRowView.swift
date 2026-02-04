//
//  UserRowView.swift
//  gym app
//
//  Reusable user row component with avatar and trailing content
//

import SwiftUI

struct UserRowView<TrailingContent: View>: View {
    let profile: UserProfile
    var avatarSize: CGFloat = 48
    var avatarColor: Color = AppColors.dominant
    var subtitle: String? = nil
    var showUsername: Bool = true
    @ViewBuilder let trailing: () -> TrailingContent

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ProfilePhotoView(
                profile: profile,
                size: avatarSize,
                backgroundColor: avatarColor.opacity(0.2),
                foregroundColor: avatarColor,
                borderColor: avatarColor.opacity(0.3)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName ?? profile.username)
                    .headline(color: AppColors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .caption(color: AppColors.textSecondary)
                } else if showUsername {
                    Text("@\(profile.username)")
                        .caption(color: AppColors.textSecondary)
                }
            }

            Spacer()

            trailing()
        }
    }
}

// Convenience initializer for no trailing content
extension UserRowView where TrailingContent == EmptyView {
    init(
        profile: UserProfile,
        avatarSize: CGFloat = 48,
        avatarColor: Color = AppColors.dominant,
        subtitle: String? = nil,
        showUsername: Bool = true
    ) {
        self.profile = profile
        self.avatarSize = avatarSize
        self.avatarColor = avatarColor
        self.subtitle = subtitle
        self.showUsername = showUsername
        self.trailing = { EmptyView() }
    }
}

#Preview {
    VStack(spacing: 0) {
        UserRowView(profile: UserProfile(username: "johndoe")) {
            Image(systemName: "chevron.right")
                .foregroundColor(AppColors.textTertiary)
        }
        .padding()

        Divider()

        UserRowView(profile: UserProfile(username: "janedoe"))
            .padding()
    }
}
