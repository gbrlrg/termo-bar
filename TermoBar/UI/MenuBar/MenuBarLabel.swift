import SwiftUI

/// O que aparece na barra de menus, conforme as preferências.
struct MenuBarLabel: View {
    @Environment(Monitor.self) private var monitor
    @Environment(Preferences.self) private var preferences

    /// Um valor da barra, com o ícone opcional que vem antes dele.
    private struct Segment {
        var symbol: String?
        var text: String
    }

    private enum Symbol {
        static let temperature = "thermometer.medium"
        static let power = "bolt.fill"
        static let fan = "fan.fill"
    }

    var body: some View {
        let temperature = monitor.currentTemperature
        let style = effectiveStyle(temperature: temperature)
        let segments = segments(style: style, temperature: temperature)

        if segments.isEmpty {
            Image(systemName: Symbol.temperature)
        } else if let image = renderedImage(segments) {
            Image(nsImage: image)
        } else {
            content(segments)
        }
    }

    /// Enquanto estiver frio, o modo compacto mostra só o ícone.
    private func effectiveStyle(temperature: Double?) -> MenuBarStyle {
        let isCool = (temperature ?? 0) < preferences.compactThreshold
        if preferences.compactWhenCool && isCool { return .icon }
        let style = preferences.menuBarStyle
        return style.showsFan && !monitor.hasFans ? .temperature : style
    }

    private func segments(style: MenuBarStyle, temperature: Double?) -> [Segment] {
        guard style.showsTemperature else { return [] }
        let icons = preferences.showValueIcons
        let value =
            temperature.map { preferences.format($0).replacingOccurrences(of: " ", with: "") }
            ?? "--\(preferences.unit.symbol)"
        var segments = [Segment(symbol: icons ? Symbol.temperature : nil, text: value)]
        if style.showsFan, let rpm = monitor.current?.fanSpeed {
            segments.append(Segment(symbol: icons ? Symbol.fan : nil, text: rpm.formatted(.rpm)))
        } else if style.showsPower, let watts = monitor.currentPower {
            segments.append(Segment(symbol: icons ? Symbol.power : nil, text: watts.formatted(.watts)))
        }
        return segments
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
