import SwiftUI

/// O que aparece na barra de menus, conforme as preferências.
struct MenuBarLabel: View {
    @Environment(Monitor.self) private var monitor
    @Environment(Preferences.self) private var preferences

    private static let iconName = "thermometer.medium"

    var body: some View {
        let temperature = monitor.currentTemperature
        let style = effectiveStyle(temperature: temperature)
        let text = text(style: style, temperature: temperature)

        HStack(spacing: 3) {
            if style.showsIcon { Image(systemName: Self.iconName) }
            if let text {
                if let temperature, let image = coloredImage(text, temperature: temperature) {
                    Image(nsImage: image)
                } else {
                    Text(text).monospacedDigit()
                }
            }
        }
    }

    /// Enquanto estiver frio, o modo compacto mostra só o ícone.
    private func effectiveStyle(temperature: Double?) -> MenuBarStyle {
        let isCool = (temperature ?? 0) < preferences.compactThreshold
        if preferences.compactWhenCool && isCool { return .icon }
        let style = preferences.menuBarStyle
        return style.showsFan && !monitor.hasFans ? .temperature : style
    }

    private func text(style: MenuBarStyle, temperature: Double?) -> String? {
        guard style.showsTemperature else { return nil }
        let value =
            temperature.map { preferences.format($0).replacingOccurrences(of: " ", with: "") }
            ?? "--\(preferences.unit.symbol)"
        if style.showsFan, let rpm = monitor.current?.fanSpeed {
            return "\(value) · \(rpm.formatted(.rpm))"
        }
        guard style.showsPower, let watts = monitor.currentPower else { return value }
        return "\(value) · \(watts.formatted(.watts))"
    }

    /// A barra pinta o rótulo como modelo (monocromático); a cor exige uma imagem pronta.
    private func coloredImage(_ text: String, temperature: Double) -> NSImage? {
        guard preferences.colorWhenHot, temperature >= Theme.hotTemperature else { return nil }
        let renderer = ImageRenderer(
            content: Text(text)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.temperatureColor(temperature)))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}
