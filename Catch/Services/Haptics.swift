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
        .catchInteractiveGlass(in: Circle())
        .accessibilityLabel(systemName == "xmark" ? "Close" : systemName)
    }
}


extension View {
    @ViewBuilder
    func catchInteractiveGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
    }

    @ViewBuilder
    func catchRegularGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
    }

    @ViewBuilder
    func catchInteractiveGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive())
        } else {
            self.background(.ultraThinMaterial)
        }
    }
}
