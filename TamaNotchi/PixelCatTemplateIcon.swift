import AppKit

/// Gato pixel-art 16×16 como plantilla (se adapta al tema de la barra de menús).
enum PixelCatTemplateIcon {
    private static let rows: [String] = [
        "0000110000110000",
        "0001111001111000",
        "0011111111111100",
        "0111111111111110",
        "0111101111011110",
        "0111101111011110",
        "0111111111111110",
        "0111111001111110",
        "0011111111111100",
        "0011011111110110",
        "0001111111111000",
        "0000111111110000",
        "0000111001110000",
        "0000011111100000",
        "0000001111000000",
        "0000000110000000",
    ]

    /// Icono cuadrado para `NSStatusItem` (~18 pt).
    static func make(pointSize: CGFloat = 18) -> NSImage {
        let rowCount = rows.count
        let colCount = rows.first?.count ?? 16
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size, flipped: false) { dst in
            NSGraphicsContext.current?.cgContext.interpolationQuality = .none
            NSColor.black.setFill()
            let cell = min(dst.width / CGFloat(colCount), dst.height / CGFloat(rowCount))
            let ox = (dst.width - cell * CGFloat(colCount)) * 0.5
            let oy = (dst.height - cell * CGFloat(rowCount)) * 0.5
            for (ri, row) in rows.enumerated() {
                for (ci, ch) in row.enumerated() where ch == "1" {
                    let r = CGRect(
                        x: ox + CGFloat(ci) * cell,
                        y: oy + CGFloat(rowCount - 1 - ri) * cell,
                        width: cell,
                        height: cell
                    )
                    NSBezierPath(rect: r).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
