//
//  ProfileEditView.swift
//  gym app
//
//  Legacy compatibility wrapper.
//  Profile editing is centralized in AccountProfileView.
//

import SwiftUI

struct ProfileEditView: View {
    init(profileRepository: ProfileRepository, isNewProfile: Bool = false) {
        _ = profileRepository
        _ = isNewProfile
    }

    var body: some View {
        AccountProfileView()
    }
}

#Preview {
    NavigationStack {
        ProfileEditView(profileRepository: ProfileRepository(persistence: .preview))
    }
}
