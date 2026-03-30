import SwiftUI

/// Barra de estadística 0…100 (compacta, estilo isla).
struct StatBarView: View {
    enum GrowDirection {
        case fromLeading
        case fromTrailing
    }

    var value: Double
    var tint: Color
    var width: CGFloat
    var height: CGFloat
    var growDirection: GrowDirection = .fromLeading

    private var ratio: CGFloat {
        CGFloat(min(100, max(0, value)) / 100)
    }

    private var fillWidth: CGFloat {
        max(height * 0.35, width * ratio)
    }

    var body: some View {
        let alignment: Alignment = growDirection == .fromLeading ? .leading : .trailing
        ZStack(alignment: alignment) {
            RoundedRectangle(cornerRadius: max(1, height * 0.22), style: .continuous)
                .fill(Color.white.opacity(0.14))
            RoundedRectangle(cornerRadius: max(1, height * 0.22), style: .continuous)
                .fill(tint.opacity(0.95))
                .frame(width: fillWidth)
        }
        .frame(width: width, height: height)
        .animation(.easeOut(duration: 0.22), value: ratio)
    }
}
