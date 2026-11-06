import Charts
import SwiftUI

/// Rotação das ventoinhas no mesmo eixo de tempo da temperatura: mostra quando giraram e quão rápido.
struct FanChart: View {
    let summary: RangeSummary
    @Binding var hoverDate: Date?

    /// Teto mínimo da escala (rpm), para que poucas rpm não ocupem o gráfico inteiro.
    private static let minimumCeiling = 1000.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardTitle(title: "Ventilador", detail: detail)
            chart
        }
    }

    private var readings: [Sample] { summary.samples.filter { $0.fanSpeed != nil } }

    private var detail: String { ChartDetails.fan(summary, hoverDate: hoverDate) }

    private var chart: some View {
        let readings = readings
        let ceiling = max(readings.compactMap(\.fanSpeed).max() ?? 0, Self.minimumCeiling)
        // Neutro: as cores dos gráficos ficam para a temperatura e para os apps.
        let fill = LinearGradient(
            colors: [Color.primary.opacity(0.16), Color.primary.opacity(0.03)], startPoint: .top, endPoint: .bottom)

        return Chart {
            ForEach(readings, id: \.date) { sample in
                let rpm = sample.fanSpeed ?? 0
                AreaMark(x: .value("Hora", sample.date), y: .value("rpm", rpm))
                    .foregroundStyle(fill)
                    .interpolationMethod(.stepEnd)
                LineMark(x: .value("Hora", sample.date), y: .value("rpm", rpm))
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.stepEnd)
            }
            if let hoverDate {
                ChartStyle.hoverRule(at: hoverDate)
            }
        }
        .chartXScale(domain: summary.start...summary.end)
        .chartYScale(domain: 0...ceiling * 1.1)
        .chartXAxis(.hidden)
        .chartYAxis { ChartStyle.quietYAxis { $0.formatted(.number.notation(.compactName)) } }
        .chartXSelection(value: $hoverDate)
        .frame(height: 44)
    }
}
