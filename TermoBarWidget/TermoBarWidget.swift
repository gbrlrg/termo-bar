import SwiftUI
import WidgetKit

/// Temperatura do chip e os apps que mais aquecem, publicados pelo TermoBar a cada registro.
@main
struct TermoBarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.kind, provider: Provider()) { entry in
            WidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
        }
        .containerBackgroundRemovable()
        .configurationDisplayName("TermoBar")
        .description("Temperatura do chip e os apps que mais aquecem.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Lê o último resumo gravado pelo app. Quem pede para redesenhar é o app; o pedido daqui é só a rede de segurança.
struct Provider: TimelineProvider {
    private static let refresh: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: .now, snapshot: WidgetSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(Self.refresh))))
    }
}

extension WidgetSnapshot {
    static let placeholder = WidgetSnapshot(
        date: .now, celsius: 62, temperature: "62 °C", pressure: .nominal,
        apps: [
            App(id: "a", name: "Xcode", watts: "4,2 W", share: 0.48, colorSlot: 0),
            App(id: "b", name: "Safari", watts: "1,9 W", share: 0.22, colorSlot: 1),
            App(id: "c", name: "Mail", watts: "0,6 W", share: 0.07, colorSlot: 2),
        ])

    /// Sem registro recente, o app provavelmente está fechado e os números estão velhos.
    var isStale: Bool { Date.now.timeIntervalSince(date) > 15 * 60 }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot?

    var body: some View {
        if let snapshot {
            switch family {
            case .systemMedium:
                HStack(spacing: 14) {
                    TemperatureView(snapshot: snapshot)
                    Rectangle().fill(.quaternary).frame(width: 1).padding(.vertical, 2)
                    AppsView(apps: snapshot.apps)
                }
            default:
                TemperatureView(snapshot: snapshot)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Header()
                Spacer(minLength: 0)
                Text("Abra o TermoBar para ver a temperatura aqui.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct Header: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "thermometer.medium")
            Text("TermoBar")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

private struct TemperatureView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header()
            Spacer(minLength: 4)
            temperature
            Text(snapshot.pressure.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(snapshot.pressure.color)
                .padding(.bottom, 8)
            TemperatureScale(celsius: snapshot.celsius)
            Spacer(minLength: 6)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// "78,0" grande e "°C" menor, como no popover.
    private var temperature: some View {
        let parts = snapshot.temperature.split(separator: " ", maxSplits: 1)
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(parts.first.map(String.init) ?? snapshot.temperature)
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.temperatureColor(snapshot.celsius))
            if parts.count > 1 {
                Text(parts[1])
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    private var footer: some View {
        if snapshot.isStale {
            Text("Abra o TermoBar para atualizar.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if family == .systemSmall, let top = snapshot.apps.first {
            AppLine(app: top)
        } else {
            Text(snapshot.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

/// Onde a temperatura está na escala de frio a quente, com as cores do gráfico do popover.
private struct TemperatureScale: View {
    let celsius: Double

    private static let range = 40.0...100.0

    var body: some View {
        let span = Self.range.upperBound - Self.range.lowerBound
        let fraction = (min(max(celsius, Self.range.lowerBound), Self.range.upperBound) - Self.range.lowerBound) / span
        let stops = stride(from: Self.range.lowerBound, through: Self.range.upperBound, by: 10).map {
            Gradient.Stop(color: Theme.temperatureColor($0), location: ($0 - Self.range.lowerBound) / span)
        }
        GeometryReader { proxy in
            Capsule()
                .fill(LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing))
                .opacity(0.85)
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(Theme.temperatureColor(celsius))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .frame(width: 10, height: 10)
                        .offset(x: (proxy.size.width - 10) * fraction)
                }
                .frame(maxHeight: .infinity)
        }
        .frame(height: 10)
    }
}

/// Ponto na cor do app, nome e watts.
private struct AppLine: View {
    let app: WidgetSnapshot.App

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.seriesColor(slot: app.colorSlot))
                .frame(width: 6, height: 6)
            Text(app.name).lineLimit(1)
            Spacer(minLength: 4)
            Text(app.watts)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

private struct AppsView: View {
    let apps: [WidgetSnapshot.App]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Apps que mais aquecem")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            if apps.isEmpty {
                Text("Nenhum app gastando energia.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 9) {
                ForEach(apps) { app in
                    VStack(alignment: .leading, spacing: 4) {
                        AppLine(app: app)
                        ShareBar(share: app.share, color: Theme.seriesColor(slot: app.colorSlot))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Fatia da energia de um app, como a barra da lista no popover.
private struct ShareBar: View {
    let share: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(.quaternary)
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: proxy.size.width * min(max(share, 0), 1))
                }
        }
        .frame(height: 3)
    }
}
