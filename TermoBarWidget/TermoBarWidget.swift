import SwiftUI
import WidgetKit

/// Temperatura do chip e os apps que mais aquecem, publicados pelo TermoBar a cada registro.
@main
struct TermoBarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.kind, provider: Provider()) { entry in
            WidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
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
                HStack(alignment: .top, spacing: 16) {
                    TemperatureView(snapshot: snapshot)
                    AppsView(apps: snapshot.apps)
                }
            default:
                TemperatureView(snapshot: snapshot)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label("TermoBar", systemImage: "thermometer.medium").font(.headline)
                Text("Abra o TermoBar para ver a temperatura aqui.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct TemperatureView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("TermoBar", systemImage: "thermometer.medium")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(snapshot.temperature)
                .font(.system(size: 34, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.temperatureColor(snapshot.celsius))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Label(snapshot.pressure.label, systemImage: snapshot.pressure.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(snapshot.pressure.color)
            Spacer(minLength: 0)
            if snapshot.isStale {
                Text("Abra o TermoBar para atualizar.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if family == .systemSmall, let top = snapshot.apps.first {
                Text("\(top.name) · \(top.watts)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(snapshot.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct AppsView: View {
    let apps: [WidgetSnapshot.App]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Apps que mais aquecem")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if apps.isEmpty {
                Text("Nenhum app gastando energia.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(apps) { app in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(app.name).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(app.watts).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    ShareBar(share: app.share, color: Theme.seriesColor(slot: app.colorSlot))
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
        .frame(height: 4)
    }
}
