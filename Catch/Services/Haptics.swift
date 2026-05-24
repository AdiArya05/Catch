import UIKit
import SwiftUI

enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

struct GlassCircleIconButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemName: String
    var size: CGFloat = 52
    var iconSize: CGFloat = 20
    var foregroundColor: Color = .secondary
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(systemName == "xmark" ? "Close" : systemName)
    }
}
