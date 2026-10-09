import SwiftUI

struct OwlMateLogo: View {
    var size: CGFloat = 64

    var body: some View {
        Image("OwlMateLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityLabel("OwlMate owl logo")
    }
}
