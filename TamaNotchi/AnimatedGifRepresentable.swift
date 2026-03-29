import AppKit
import SwiftUI

final class BoundedGifContainer: NSView {
    let imageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignBottom
        imageView.animates = true
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)

        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct AnimatedGifRepresentable: NSViewRepresentable {
    var url: URL?
    var layoutSize: CGSize = CGSize(
        width: NotchWindowMetrics.petLogicalWidth,
        height: NotchWindowMetrics.petLogicalHeight
    )

    func makeNSView(context: Context) -> BoundedGifContainer {
        BoundedGifContainer()
    }

    func updateNSView(_ container: BoundedGifContainer, context: Context) {
        let iv = container.imageView
        iv.animates = true
        if let url {
            iv.image = NSImage(contentsOf: url)
        } else {
            iv.image = nil
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BoundedGifContainer, context: Context) -> CGSize? {
        layoutSize
    }
}
