import SwiftUI

/// Temperatura atual em destaque, estado térmico e números de apoio.
struct HeaderView: View {
    @Environment(Monitor.self) private var monitor
    @Environment(Preferences.self) private var preferences
    let summary: RangeSummary

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(monitor.chipName) · \(preferences.source.label.lowercased())")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                currentTemperature
                PressureBadge(pressure: monitor.pressure)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                if let current = monitor.current {
                    let alternate = preferences.source.alternate
                    Stat(title: alternate.label, value: preferences.format(current.temperature(for: alternate)))
                }
                Stat(title: "Apps agora", value: monitor.currentPower?.formatted(.watts) ?? "—")
                Stat(title: "Mín · Máx", value: temperatureRange ?? "—")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
    }

    private var currentTemperature: some View {
        let temperature = monitor.currentTemperature
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(temperature.map { preferences.format($0, symbol: false) } ?? "--")
                .font(.system(size: 44, weight: .semibold))
                .contentTransition(.numericText(value: temperature ?? 0))
                .animation(.snappy, value: temperature)
            Text(preferences.unit.symbol)
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .monospacedDigit()
    }

    private var temperatureRange: String? {
        let temperatures = summary.samples.map(monitor.temperature(of:))
        guard let low = temperatures.min(), let high = temperatures.max() else { return nil }
        return "\(preferences.short(low)) · \(preferences.short(high))"
    }
}

private struct PressureBadge: View {
    let pressure: ThermalPressure

    var body: some View {
        Label(pressure.label, systemImage: pressure.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(pressure.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(pressure.color.opacity(0.14), in: Capsule())
            .help("Pressão térmica informada pelo kernel do macOS")
    }
}
