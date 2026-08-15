import SwiftUI

/// Janela que abre ao clicar na barra de menus.
struct PopoverView: View {
    @Environment(Monitor.self) private var monitor

    @AppStorage("range") private var range: TimeRange = .hour
    @State private var hoverDate: Date?
    /// App sob o cursor na lista; destacado no gráfico de energia.
    @State private var hoveredApp: String?
    /// App fixado com um clique; tem prioridade sobre o cursor.
    @State private var pinnedApp: String?

    var body: some View {
        let summary = monitor.summary(range: range)
        VStack(spacing: 10) {
            HeaderView(summary: summary)
            ChartsCard(summary: summary, range: $range, hoverDate: $hoverDate, focusedApp: pinnedApp ?? hoveredApp)
            if summary.hasEnoughData {
                AppListCard(summary: summary, hoveredApp: $hoveredApp, pinnedApp: $pinnedApp)
            }
            FooterView()
        }
        .padding(12)
        .frame(width: 360)
        .animation(.smooth(duration: 0.25), value: range)
    }
}
