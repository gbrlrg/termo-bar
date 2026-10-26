import SwiftUI

/// Os anéis do ícone do app em tons neutros, para identificar o TermoBar sem competir com os dados.
struct BrandMark: View {
    /// Quadrados arredondados do ícone (`AppIcon.icon`), do maior ao menor, em coordenadas de 1024 pt.
    private static let rings: [(frame: CGRect, radius: CGFloat)] = [
        (CGRect(x: 132, y: 132, width: 760, height: 760), 182),
        (CGRect(x: 207, y: 185, width: 630, height: 630), 151),
        (CGRect(x: 280, y: 236, width: 505, height: 505), 121),
        (CGRect(x: 350, y: 284, width: 385, height: 385), 92),
        (CGRect(x: 417, y: 329, width: 270, height: 270), 65),
        (CGRect(x: 487, y: 377, width: 150, height: 150), 36),
    ]
    private static let canvas: CGFloat = 760
    private static let origin = CGPoint(x: 132, y: 132)

    var body: some View {
        Canvas { context, size in
            let scale = size.width / Self.canvas
            for (index, ring) in Self.rings.enumerated() {
                let frame = CGRect(
                    x: (ring.frame.minX - Self.origin.x) * scale, y: (ring.frame.minY - Self.origin.y) * scale,
                    width: ring.frame.width * scale, height: ring.frame.height * scale)
                // Anéis alternados: em 12 pt, os seis juntos viram um quadrado só.
                guard index.isMultiple(of: 2) || index == Self.rings.count - 1 else { continue }
                context.opacity = index == Self.rings.count - 1 ? 0.45 : 0.16
                context.fill(Path(roundedRect: frame, cornerRadius: ring.radius * scale), with: .foreground)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Linha fina com a marca e o nome do app, no alto do popover.
struct BrandBar: View {
    var body: some View {
        HStack(spacing: 5) {
            BrandMark().frame(width: 13, height: 13)
            Text(verbatim: "TermoBar")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
