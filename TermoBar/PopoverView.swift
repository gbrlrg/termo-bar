import Charts
import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let monitor: Monitor
    @State private var prefs = Preferences.shared

    @AppStorage("range") private var range: TimeRange = .hour
    @State private var hoverDate: Date?
    /// App em foco: destacado no gráfico de energia, os outros esmaecem.
    @State private var focusedApp: String?
    @State private var pinnedApp: String?

    var body: some View {
        let summary = monitor.summary(range: range)
        VStack(spacing: 10) {
            HeaderView(monitor: monitor, summary: summary, prefs: prefs)
            ChartsCard(monitor: monitor, summary: summary, prefs: prefs, range: $range, hoverDate: $hoverDate,
                       focusedApp: pinnedApp ?? focusedApp)
            if summary.samples.count >= 3 {
                AppListCard(monitor: monitor, summary: summary, focusedApp: $focusedApp, pinnedApp: $pinnedApp)
            }
            FooterView()
        }
        .padding(12)
        .frame(width: 360)
        .animation(.smooth(duration: 0.25), value: range)
    }
}

// MARK: - Cabeçalho

private struct HeaderView: View {
    let monitor: Monitor
    let summary: RangeSummary
    let prefs: Preferences

    var body: some View {
        let pressure = monitor.pressure
        let temp = monitor.current.map(monitor.temperature(of:))
        let temps = summary.samples.map(monitor.temperature(of:))
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(monitor.chipName) · \(prefs.source.label.lowercased())")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(temp.map { prefs.format($0, symbol: false) } ?? "--")
                        .font(.system(size: 44, weight: .semibold))
                        .contentTransition(.numericText(value: temp ?? 0))
                        .animation(.snappy, value: temp)
                    Text(prefs.unit.symbol)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
                Label(pressure.label, systemImage: pressure.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(pressure.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(pressure.color.opacity(0.14), in: Capsule())
                    .help("Pressão térmica informada pelo kernel do macOS")
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                if let current = monitor.current {
                    Stat(title: prefs.source == .average ? "Ponto mais quente" : "Média do chip",
                         value: prefs.format(prefs.source == .average ? current.maxTemp : current.temp))
                }
                Stat(title: "Apps agora", value: monitor.currentPower.map(formatWatts) ?? "—")
                Stat(title: "Mín · Máx", value: temps.min().map { lo in
                    "\(prefs.short(lo)) · \(prefs.short(temps.max() ?? lo))"
                } ?? "—")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
    }
}

private struct Stat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.semibold)).monospacedDigit()
        }
    }
}

private struct CollectingView: View {
    let range: TimeRange

    var body: some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(range.usesMinutes ? "O histórico de \(range.label) se forma com o uso." : "Coletando dados…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Gráficos

private struct ChartsCard: View {
    let monitor: Monitor
    let summary: RangeSummary
    let prefs: Preferences
    @Binding var range: TimeRange
    @Binding var hoverDate: Date?
    let focusedApp: String?

    private var hovered: Sample? { hoverDate.flatMap { monitor.sample(near: $0, in: summary.samples) } }
    private func temp(_ sample: Sample) -> Double { monitor.temperature(of: sample) }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Período", selection: $range) {
                    ForEach(TimeRange.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
                .frame(maxWidth: .infinity)

                if summary.samples.count < 3 {
                    CollectingView(range: range)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        CardTitle(title: "Temperatura", detail: temperatureDetail)
                        temperatureChart
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        CardTitle(title: "Energia por app", detail: energyDetail)
                        energyChart
                    }
                }
            }
        }
    }

    private var dateFormat: Date.FormatStyle {
        range.usesMinutes ? .dateTime.weekday(.abbreviated).hour().minute() : .dateTime.hour().minute().second()
    }

    private var temperatureDetail: String {
        if let h = hovered {
            return "\(h.date.formatted(dateFormat))  \(prefs.format(temp(h), decimals: 1))"
        }
        let weighted = summary.samples.reduce(0) { $0 + temp($1) * $1.duration }
        let duration = summary.samples.reduce(0) { $0 + $1.duration }
        return duration > 0 ? "média \(prefs.format(weighted / duration, decimals: 1))" : ""
    }

    private var energyDetail: String {
        if let date = hoverDate {
            let bin = summary.bin(for: date)
            let total = summary.binTotals[bin] ?? 0
            let top = summary.slices.filter { $0.start == bin && $0.app != Monitor.othersID }
                .max { ($0.high - $0.low) < ($1.high - $1.low) }
            if let top { return "\(monitor.name(top.app)) \(formatWatts(top.high - top.low)) de \(formatWatts(total))" }
            return formatWatts(total)
        }
        let energy = summary.rows.reduce(0) { $0 + $1.energy.total }
        return summary.measured > 0 ? "média \(formatWatts(energy / summary.measured))" : ""
    }

    // Linha colorida pela temperatura, área esmaecendo e faixas de limitação térmica.
    private var temperatureChart: some View {
        let temps = summary.samples.map(temp)
        let lo = temps.min() ?? 40, hi = temps.max() ?? 80
        let unit = prefs.unit
        let floor = (unit.convert(lo) - unit.convertDelta(2)).rounded(.down)
        let ceil = (unit.convert(hi) + unit.convertDelta(2)).rounded(.up)
        return Chart {
            ForEach(Array(summary.throttled.enumerated()), id: \.offset) { _, span in
                RectangleMark(xStart: .value("Início", span.lowerBound), xEnd: .value("Fim", span.upperBound))
                    .foregroundStyle(Theme.serious.opacity(0.14))
            }
            ForEach(summary.samples, id: \.date) { s in
                AreaMark(x: .value("Hora", s.date), yStart: .value("Base", floor), yEnd: .value("Temperatura", unit.convert(temp(s))))
                    .foregroundStyle(LinearGradient(colors: [Theme.temperatureColor(hi).opacity(0.22), .clear],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Hora", s.date), y: .value("Temperatura", unit.convert(temp(s))))
                    .foregroundStyle(Theme.temperatureGradient(lo...hi))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let h = hovered {
                RuleMark(x: .value("Hora", h.date))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Hora", h.date), y: .value("Temperatura", unit.convert(temp(h))))
                    .symbol {
                        Circle()
                            .fill(Theme.temperatureColor(temp(h)))
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(.background, lineWidth: 2))
                    }
            }
        }
        .chartXScale(domain: summary.start...summary.end)
        .chartYScale(domain: floor...ceil)
        .chartXAxis(.hidden)
        .chartYAxis { quietYAxis { "\(Int($0))°" } }
        .chartXSelection(value: $hoverDate)
        .frame(height: 96)
    }

    // Barras empilhadas por faixa de tempo, como em Ajustes > Bateria.
    private var energyChart: some View {
        let ids = summary.stacked + [Monitor.othersID]
        return VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(summary.slices) { slice in
                    RectangleMark(
                        xStart: .value("Início", slice.start),
                        xEnd: .value("Fim", slice.start.addingTimeInterval(summary.binSize * 0.72)),
                        yStart: .value("W", slice.low),
                        yEnd: .value("W", slice.high))
                        .foregroundStyle(color(slice.app).opacity(dimmed(slice.app) ? 0.18 : 1))
                        .cornerRadius(1)
                }
                if let date = hoverDate {
                    RuleMark(x: .value("Hora", date))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXScale(domain: summary.start...summary.end)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisValueLabel(format: range == .week ? .dateTime.weekday(.abbreviated) : .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                }
            }
            .chartYAxis { quietYAxis { $0.formatted(.number.precision(.fractionLength(0))) + " W" } }
            .chartXSelection(value: $hoverDate)
            .frame(height: 84)

            FlowLayout(spacing: 10) {
                ForEach(ids, id: \.self) { id in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(color(id))
                            .frame(width: 8, height: 8)
                        Text(monitor.name(id)).lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .opacity(dimmed(id) ? 0.4 : 1)
                }
            }
        }
    }

    private func color(_ id: String) -> Color {
        monitor.slots[id].map { Theme.series[$0] } ?? Theme.others
    }

    private func dimmed(_ id: String) -> Bool {
        guard let focusedApp else { return false }
        let focus = summary.stacked.contains(focusedApp) ? focusedApp : Monitor.othersID
        return id != focus
    }
}

/// Eixo Y discreto: grade fina e rótulos terciários à direita.
private func quietYAxis(_ label: @escaping (Double) -> String) -> some AxisContent {
    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
            .foregroundStyle(Color(nsColor: .separatorColor))
        AxisValueLabel {
            if let v = value.as(Double.self) { Text(label(v)) }
        }
        .font(.caption2)
        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
    }
}

// MARK: - Lista de apps

private struct AppListCard: View {
    let monitor: Monitor
    let summary: RangeSummary
    @Binding var focusedApp: String?
    @Binding var pinnedApp: String?

    @State private var expanded = false
    private let collapsedCount = 5

    var body: some View {
        let rows = expanded ? summary.rows : Array(summary.rows.prefix(collapsedCount))
        Card {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(title: "Apps que mais aquecem", detail: "energia no período")
                VStack(spacing: 2) {
                    ForEach(rows) { row in
                        AppRowView(monitor: monitor, summary: summary, row: row,
                                   highlighted: (pinnedApp ?? focusedApp) == row.id)
                            .onHover { focusedApp = $0 ? row.id : (focusedApp == row.id ? nil : focusedApp) }
                            .onTapGesture { pinnedApp = pinnedApp == row.id ? nil : row.id }
                    }
                }
                if summary.rows.count > collapsedCount {
                    Button {
                        withAnimation(.smooth) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(expanded ? "Mostrar menos" : "Mostrar todos os \(summary.rows.count) apps")
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(expanded ? 180 : 0))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                Text("Inclui os processos que cada app abre e a GPU de todos. A CPU de processos do sistema não entra na conta.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AppRowView: View {
    let monitor: Monitor
    let summary: RangeSummary
    let row: AppRow
    let highlighted: Bool

    var body: some View {
        let tint = monitor.slots[row.id].map { Theme.series[$0] }
        HStack(spacing: 10) {
            AppIcon(id: row.id)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if row.share >= 0.005 {
                        if row.average.gpu >= 0.05 {
                            Text("GPU")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }
                        Text(formatWatts(row.average.total))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(row.share.formatted(.percent.precision(.fractionLength(0))))
                            .font(.callout.weight(.semibold))
                            .frame(minWidth: 34, alignment: .trailing)
                    } else {
                        Text("ocioso").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .monospacedDigit()
                HeatStrip(row: row, summary: summary, tint: tint ?? .secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(highlighted ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .help("CPU \(formatWatts(row.average.cpu)) · GPU \(formatWatts(row.average.gpu)) em média. Clique para destacar no gráfico.")
    }
}

/// Linha do tempo do app: aberto (trilho) e consumo (cor mais forte = mais watts).
private struct HeatStrip: View {
    let row: AppRow
    let summary: RangeSummary
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let span = summary.end.timeIntervalSince(summary.start)
            func x(_ date: Date) -> CGFloat {
                CGFloat(min(max(date.timeIntervalSince(summary.start) / span, 0), 1)) * size.width
            }
            context.fill(Capsule().path(in: CGRect(origin: .zero, size: size)), with: .style(.fill.quaternary))
            for range in row.open {
                let rect = CGRect(x: x(range.lowerBound), y: 0, width: max(x(range.upperBound) - x(range.lowerBound), 1), height: size.height)
                context.fill(Capsule().path(in: rect), with: .style(.fill.tertiary))
            }
            for (start, watts) in row.heat where watts >= 0.02 {
                let strength = min(watts / summary.peakHeat, 1)
                let x0 = x(start), x1 = x(start.addingTimeInterval(summary.binSize))
                let rect = CGRect(x: x0, y: 0, width: max(x1 - x0, 1.5), height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(tint.opacity(0.3 + 0.7 * strength)))
            }
        }
        .frame(height: 5)
        .clipShape(Capsule())
    }
}

// MARK: - Rodapé

private struct FooterView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack {
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
            } label: {
                Label("Monitor de Atividade", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("Ajustes…") {
                    NSApp.activate()
                    openSettings()
                }
                .keyboardShortcut(",")
                Toggle("Abrir ao iniciar sessão", isOn: $launchAtLogin)
                Divider()
                Button("Sair do TermoBar") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.horizontal, 6)
        .onChange(of: launchAtLogin) { _, on in
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }
}

// MARK: - Peças

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CardTitle: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText())
        }
    }
}

/// Quebra linha quando os itens não cabem na largura (legenda).
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, point) in zip(subviews, arrange(width: bounds.width, subviews: subviews).points) {
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + 4
                lineHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: maxX, height: y + lineHeight), points)
    }
}

private struct AppIcon: View {
    let id: String

    @MainActor private static var cache: [String: NSImage] = [:]
    // Grupos sem app instalado (ex.: simuladores rodando sem o Simulator.app).
    private static let symbols = ["com.apple.iphonesimulator": "iphone"]
    // Apps fora das pastas que o LaunchServices indexa.
    private static let knownPaths = [
        "com.apple.iphonesimulator": "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app",
    ]

    var body: some View {
        if let image = Self.icon(for: id) {
            Image(nsImage: image).resizable().frame(width: 24, height: 24)
        } else {
            Image(systemName: Self.symbols[id] ?? "gearshape.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .padding(1)
        }
    }

    @MainActor
    private static func icon(for id: String) -> NSImage? {
        if let cached = cache[id] { return cached }
        guard !id.hasPrefix("proc:") else { return nil }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            ?? knownPaths[id].map { URL(fileURLWithPath: $0) }
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache[id] = image
        return image
    }
}

