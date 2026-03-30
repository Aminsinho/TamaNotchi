import AppKit
import SwiftUI

/// Título en una línea con desplazamiento suave si no cabe (estilo cartel).
struct MarqueeTitleView: View {
    let text: String
    var fontSize: CGFloat = 8
    var cycleSeconds: Double = 9

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: text.isEmpty)) { context in
            MarqueeTimelineContent(
                text: text,
                fontSize: fontSize,
                cycleSeconds: cycleSeconds,
                date: context.date
            )
        }
    }

    private struct MarqueeTimelineContent: View {
        let text: String
        let fontSize: CGFloat
        let cycleSeconds: Double
        let date: Date

        var body: some View {
            GeometryReader { geo in
                let available = max(1, geo.size.width)
                let w = measureWidth(text, fontSize: fontSize)
                if w <= available - 1 {
                    Text(text)
                        .font(.system(size: fontSize, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    let gap: CGFloat = 20
                    let travel = max(0, w - available + gap)
                    let period = cycleSeconds
                    let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period * 2)
                    let u = t < period ? CGFloat(t / period) : CGFloat(2 - t / period)
                    let x = -u * travel
                    Text(text)
                        .font(.system(size: fontSize, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: x)
                        .frame(width: available, height: geo.size.height, alignment: .leading)
                        .clipped()
                }
            }
        }

        private func measureWidth(_ str: String, fontSize: CGFloat) -> CGFloat {
            guard !str.isEmpty else { return 0 }
            let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            return (str as NSString).size(withAttributes: attrs).width
        }
    }
}
