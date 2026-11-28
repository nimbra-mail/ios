import SwiftUI
import UIKit

/// An account's avatar: its profile photo in a circle when it has one, else its initials on
/// its tone (`AvatarView`).
struct AccountAvatar: View {
    let account: Account
    var size: CGFloat = 28
    @Environment(AppModel.self) private var app

    var body: some View {
        if let data = app.accountPhotos[account.id], let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.circle)
                .accessibilityHidden(true)
        } else {
            AvatarView(person: account.person, size: size)
        }
    }
}
