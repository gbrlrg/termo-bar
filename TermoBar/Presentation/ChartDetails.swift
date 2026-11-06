import Foundation

/// Texto ao lado do título de cada gráfico do popover: o instante sob o cursor ou o resumo do período.
enum ChartDetails {
    /// Com o cursor, o total da barra e o app que mais gastou nela; sem, a média do período.
    static func energy(_ summary: RangeSummary, hoverDate: Date?, appName: (String) -> String) -> String {
        guard let hoverDate else {
            return summary.averagePower.map { String(localized: "média \($0.formatted(.watts))") } ?? ""
        }
        let bin = summary.bin(for: hoverDate)
        let total = (summary.binTotals[bin] ?? 0).formatted(.watts)
        let top = summary.slices
            .filter { $0.start == bin && $0.app != AppID.others }
            .max { $0.watts < $1.watts }
        guard let top else { return total }
        return String(localized: "\(appName(top.app)) \(top.watts.formatted(.watts)) de \(total)")
    }

    /// Com o cursor, a rotação no instante; sem, quanto do período a ventoinha girou.
    static func fan(_ summary: RangeSummary, hoverDate: Date?) -> String {
        if let hoverDate, let hovered = summary.samples.nearest(to: hoverDate) {
            let date = hovered.date.formatted(summary.range.hoverDateFormat)
            let speed =
                switch hovered.fanSpeed {
                case nil: String(localized: "sem leitura")
                case let rpm? where hovered.isFanSpinning: rpm.formatted(.rpm)
                default: String(localized: "parado")
                }
            return "\(date)  \(speed)"
        }
        guard let share = summary.samples.fanSpinningShare else { return "" }
        guard share > 0 else { return String(localized: "parado no período") }
        return String(localized: "girando \(share.formatted(.percent.precision(.fractionLength(0)))) do tempo")
    }

    /// Com o cursor, a temperatura no instante; sem, a média e a faixa do período.
    @MainActor
    static func temperature(_ summary: RangeSummary, hoverDate: Date?, preferences: Preferences) -> String {
        let source = preferences.source
        if let hoverDate, let hovered = summary.samples.nearest(to: hoverDate) {
            let date = hovered.date.formatted(summary.range.hoverDateFormat)
            return "\(date)  \(preferences.format(hovered.temperature(for: source), decimals: 1))"
        }
        let temperatures = summary.samples.map { $0.temperature(for: source) }
        guard let average = summary.samples.averageTemperature(for: source), let low = temperatures.min(),
            let high = temperatures.max()
        else { return "" }
        let mean = preferences.format(average, decimals: 1)
        return String(localized: "média \(mean) · \(preferences.short(low))–\(preferences.short(high))")
    }
}

extension TimeRange {
    /// Data do instante sob o cursor: com dia da semana nos períodos longos.
    var hoverDateFormat: Date.FormatStyle {
        usesMinuteSummaries ? .dateTime.weekday(.abbreviated).hour().minute() : .dateTime.hour().minute().second()
    }

    /// Rótulos do eixo de tempo.
    var axisDateFormat: Date.FormatStyle {
        self == .week ? .dateTime.weekday(.abbreviated) : .dateTime.hour().minute()
    }
}
