import Charts
import SwiftUI

/// Barras empilhadas de potência por app ao longo do tempo, como em Ajustes > Bateria.
struct EnergyChart: View {
    @Environment(Monitor.self) private var monitor
    let summary: RangeSummary
    @Binding var hoverDate: Date?
    let focusedApp: String?

    /// Largura de cada barra em relação à faixa de tempo, deixando um respiro entre elas.
    private static let barWidthRatio = 0.72

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardTitle(title: "Energia por app", detail: detail)
            VStack(alignment: .leading, spacing: 8) {
                chart
                legend
            }
        }
    }

    private var detail: String {
        guard let hoverDate else {
            return summary.averagePower.map { "média \($0.formatted(.watts))" } ?? ""
        }
        let bin = summary.bin(for: hoverDate)
        let total = (summary.binTotals[bin] ?? 0).formatted(.watts)
        let top = summary.slices
            .filter { $0.start == bin && $0.app != AppID.others }
            .max { $0.watts < $1.watts }
        guard let top else { return total }
        return "\(monitor.name(top.app)) \(top.watts.formatted(.watts)) de \(total)"
    }

    private var chart: some View {
        Chart {
            ForEach(summary.slices) { slice in
                RectangleMark(
                    xStart: .value("Início", slice.start),
                    xEnd: .value("Fim", slice.start.addingTimeInterval(summary.binSize * Self.barWidthRatio)),
                    yStart: .value("W", slice.low),
                    yEnd: .value("W", slice.high)
                )
                .foregroundStyle(color(slice.app).opacity(isDimmed(slice.app) ? 0.18 : 1))
                .cornerRadius(1)
            }
            if let hoverDate {
                ChartStyle.hoverRule(at: hoverDate)
            }
        }
        .chartXScale(domain: summary.start...summary.end)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisValueLabel(format: summary.range.axisDateFormat)
                    .font(.caption2)
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .chartYAxis { ChartStyle.quietYAxis { $0.formatted(.number.precision(.fractionLength(0))) + " W" } }
        .chartXSelection(value: $hoverDate)
        .frame(height: 84)
    }

    private var legend: some View {
        FlowLayout(spacing: 10) {
            ForEach(summary.stacked + [AppID.others], id: \.self) { id in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color(id))
                        .frame(width: 8, height: 8)
                    Text(monitor.name(id)).lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(isDimmed(id) ? 0.4 : 1)
            }
        }
    }

    private func color(_ id: String) -> Color {
        Theme.seriesColor(slot: monitor.palette[id])
    }

    /// Com um app em foco, os outros esmaecem; apps sem cor própria contam como "Outros".
    private func isDimmed(_ id: String) -> Bool {
        guard let focusedApp else { return false }
        let focus = summary.stacked.contains(focusedApp) ? focusedApp : AppID.others
        return id != focus
    }
}
