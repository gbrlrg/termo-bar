import Charts
import SwiftUI

/// Linha colorida pela temperatura, área esmaecendo e faixas de limitação térmica.
struct TemperatureChart: View {
    @Environment(Monitor.self) private var monitor
    @Environment(Preferences.self) private var preferences
    let summary: RangeSummary
    @Binding var hoverDate: Date?

    /// Folga acima e abaixo da linha (°C).
    private static let padding = 2.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardTitle(title: "Temperatura", detail: detail)
            chart
        }
    }

    private var hovered: Sample? { hoverDate.flatMap { summary.samples.nearest(to: $0) } }

    private func temperature(_ sample: Sample) -> Double { monitor.temperature(of: sample) }

    private var detail: String {
        if let hovered {
            let date = hovered.date.formatted(summary.range.hoverDateFormat)
            return "\(date)  \(preferences.format(temperature(hovered), decimals: 1))"
        }
        guard let average = summary.samples.averageTemperature(for: preferences.source) else { return "" }
        return "média \(preferences.format(average, decimals: 1))"
    }

    private var chart: some View {
        let temperatures = summary.samples.map(temperature)
        let low = temperatures.min() ?? 40
        let high = temperatures.max() ?? 80
        let unit = preferences.unit
        let floor = (unit.convert(low) - unit.convertDelta(Self.padding)).rounded(.down)
        let ceiling = (unit.convert(high) + unit.convertDelta(Self.padding)).rounded(.up)
        let areaFill = LinearGradient(
            colors: [Theme.temperatureColor(high).opacity(0.22), .clear], startPoint: .top, endPoint: .bottom)
        let lineFill = Theme.temperatureGradient(low...high)

        return Chart {
            ForEach(Array(summary.throttled.enumerated()), id: \.offset) { _, span in
                RectangleMark(xStart: .value("Início", span.lowerBound), xEnd: .value("Fim", span.upperBound))
                    .foregroundStyle(Theme.serious.opacity(0.14))
            }
            ForEach(summary.samples, id: \.date) { sample in
                let value = unit.convert(temperature(sample))
                AreaMark(
                    x: .value("Hora", sample.date), yStart: .value("Base", floor), yEnd: .value("Temperatura", value)
                )
                .foregroundStyle(areaFill)
                .interpolationMethod(.monotone)
                LineMark(x: .value("Hora", sample.date), y: .value("Temperatura", value))
                    .foregroundStyle(lineFill)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let hovered {
                ChartStyle.hoverRule(at: hovered.date)
                PointMark(x: .value("Hora", hovered.date), y: .value("Temperatura", unit.convert(temperature(hovered))))
                    .symbol {
                        Circle()
                            .fill(Theme.temperatureColor(temperature(hovered)))
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(.background, lineWidth: 2))
                    }
            }
        }
        .chartXScale(domain: summary.start...summary.end)
        .chartYScale(domain: floor...ceiling)
        .chartXAxis(.hidden)
        .chartYAxis { ChartStyle.quietYAxis { "\(Int($0))°" } }
        .chartXSelection(value: $hoverDate)
        .frame(height: 96)
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
