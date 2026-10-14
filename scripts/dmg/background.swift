// Desenha o fundo da janela do DMG em 1x e 2x: o app à esquerda, a seta e a pasta Aplicativos à direita.
// Uso: swift scripts/dmg/background.swift <pasta de saída>
// As posições dos ícones precisam bater com as do release.sh.
import AppKit

let size = NSSize(width: 640, height: 420)
// Centro dos ícones com a origem embaixo, como o AppKit desenha; no Finder, y = 420 - 214 = 206.
let appCenter = NSPoint(x: 170, y: 214)
let folderCenter = NSPoint(x: 470, y: 214)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerY: CGFloat) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color,
    ]
    let measured = string.size(withAttributes: attributes)
    string.draw(at: NSPoint(x: (640 - measured.width) / 2, y: centerY - measured.height / 2),
                withAttributes: attributes)
}

func draw() {
    // Fundo claro com um toque das cores do ícone, para os nomes dos ícones continuarem legíveis.
    NSGradient(colors: [color(0xFFFFFF), color(0xF6F1FF), color(0xFFF3EA)])!
        .draw(in: NSRect(origin: .zero, size: size), angle: 90)
    for (center, tint) in [(appCenter, color(0x7B3FF2, 0.10)), (folderCenter, color(0x3B82F6, 0.08))] {
        NSGradient(colors: [tint, tint.withAlphaComponent(0)])!
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: 130, options: [])
    }

    text("Instalar o TermoBar", size: 22, weight: .bold, color: color(0x1E1033), centerY: 362)
    text("Arraste o TermoBar para a pasta Aplicativos", size: 13, weight: .regular,
         color: color(0x1E1033, 0.6), centerY: 334)

    // Seta fina e escura, sem disputar atenção com os ícones.
    let arrow = NSBezierPath()
    let y = appCenter.y
    arrow.move(to: NSPoint(x: 279, y: y))
    arrow.line(to: NSPoint(x: 361, y: y))
    arrow.move(to: NSPoint(x: 349, y: y + 11))
    arrow.line(to: NSPoint(x: 361, y: y))
    arrow.line(to: NSPoint(x: 349, y: y - 11))
    arrow.lineWidth = 2.1
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor.black.withAlphaComponent(0.85).setStroke()
    arrow.stroke()

    text("Requer Mac com Apple Silicon e macOS 15 ou superior", size: 11, weight: .regular,
         color: color(0x1E1033, 0.45), centerY: 36)
}

func render(scale: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try render(scale: 1, to: out.appendingPathComponent("background.png"))
try render(scale: 2, to: out.appendingPathComponent("background@2x.png"))
