import SwiftUI

/// Seletor de período e os gráficos de temperatura e energia, no mesmo eixo de tempo.
struct ChartsCard: View {
    let summary: RangeSummary
    @Binding var range: TimeRange
    @Binding var hoverDate: Date?
    let focusedApp: String?

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

                if summary.hasEnoughData {
                    TemperatureChart(summary: summary, hoverDate: $hoverDate)
                    EnergyChart(summary: summary, hoverDate: $hoverDate, focusedApp: focusedApp)
                } else {
                    CollectingView(range: range)
                }
            }
        }
    }
}

private struct CollectingView: View {
    let range: TimeRange

    var body: some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(range.usesMinuteSummaries ? "O histórico de \(range.label) se forma com o uso." : "Coletando dados…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}
