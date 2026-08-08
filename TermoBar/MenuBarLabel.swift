import SwiftUI

/// O que aparece na barra de menus, conforme as preferências.
struct MenuBarLabel: View {
    let monitor: Monitor
    @State private var prefs = Preferences.shared

    var body: some View {
        let temp = monitor.current.map(monitor.temperature(of:))
        let cool = prefs.compactWhenCool && (temp ?? 0) < prefs.compactThreshold
        let style = cool ? .icon : prefs.menuBarStyle
        let text = text(style: style, temp: temp)

        if prefs.colorWhenHot, let temp, temp >= 75, let text, let image = Self.colored(text, color: Theme.temperatureColor(temp)) {
            // A barra pinta o rótulo como modelo (monocromático); a cor exige uma imagem pronta.
            HStack(spacing: 3) {
                if style == .iconAndTemperature { Image(systemName: "thermometer.medium") }
                Image(nsImage: image)
            }
        } else {
            HStack(spacing: 3) {
                if style == .icon || style == .iconAndTemperature { Image(systemName: "thermometer.medium") }
                if let text { Text(text).monospacedDigit() }
            }
        }
    }

    private func text(style: MenuBarStyle, temp: Double?) -> String? {
        guard style != .icon else { return nil }
        let value = temp.map { prefs.format($0).replacingOccurrences(of: " ", with: "") } ?? "--\(prefs.unit.symbol)"
        guard style == .temperatureAndPower, let watts = monitor.currentPower else { return value }
        return "\(value) · \(formatWatts(watts))"
    }

    @MainActor
    private static func colored(_ text: String, color: Color) -> NSImage? {
        let renderer = ImageRenderer(content: Text(text)
            .font(.system(size: 13, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(color))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}
