import SwiftUI

/// O que aparece na barra de menus, conforme as preferências.
struct MenuBarLabel: View {
    @Environment(Monitor.self) private var monitor
    @Environment(Preferences.self) private var preferences

    private typealias Segment = MenuBarContent.Segment

    var body: some View {
        let segments = MenuBarContent.segments(
            MenuBarContent.Reading(
                temperature: monitor.currentTemperature, fanSpeed: monitor.current?.fanSpeed,
                power: monitor.currentPower, hasFans: monitor.hasFans),
            options: MenuBarContent.Options(
                style: preferences.menuBarStyle, compactWhenCool: preferences.compactWhenCool,
                compactThreshold: preferences.compactThreshold, showValueIcons: preferences.showValueIcons,
                unitSymbol: preferences.unit.symbol)
        ) { preferences.format($0) }

        if segments.isEmpty {
            Image(systemName: MenuBarContent.Symbol.temperature)
        } else if let image = renderedImage(segments) {
            Image(nsImage: image)
        } else {
            content(segments)
        }
    }

    private func content(_ segments: [Segment]) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 { Text(verbatim: "·") }
                if let symbol = segment.symbol { Image(systemName: symbol) }
                Text(segment.text).monospacedDigit()
            }
        }
    }

    /// A barra só mostra uma imagem e um texto do rótulo: vários valores com ícones exigem uma imagem pronta,
    /// desenhada como modelo para a barra pintar na cor do tema.
    private func renderedImage(_ segments: [Segment]) -> NSImage? {
        guard segments.count > 1 else { return nil }
        let renderer = ImageRenderer(
            content: content(segments)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.black))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }
}
