import SwiftUI

/// Janela que abre ao clicar na barra de menus.
struct PopoverView: View {
    @Environment(Monitor.self) private var monitor

    @AppStorage("range") private var range: TimeRange = .hour
    @State private var hoverDate: Date?
    /// App sob o cursor na lista; destacado no gráfico de energia.
    @State private var hoveredApp: String?
    /// App fixado com um clique; tem prioridade sobre o cursor.
    @State private var pinnedApp: String? = {
        #if DEBUG
            ProcessInfo.processInfo.environment["TERMOBAR_PIN"]
        #else
            nil
        #endif
    }()

    /// Fechado, o popover mostra só um espaço do mesmo tamanho e para de acompanhar as leituras.
    @State private var isVisible = true
    @State private var height: CGFloat = 0

    var body: some View {
        Group {
            if isVisible {
                content.onGeometryChange(for: CGFloat.self, of: \.size.height) { height = $0 }
            } else {
                Color.clear.frame(width: Self.width, height: height)
            }
        }
        .onWindowVisibilityChange { isVisible = $0 }
    }

    private static let width: CGFloat = 360

    private var content: some View {
        let summary = monitor.summary(range: range)
        return VStack(spacing: 10) {
            BrandBar()
            HeaderView()
            ChartsCard(summary: summary, range: $range, hoverDate: $hoverDate, focusedApp: pinnedApp ?? hoveredApp)
            if summary.hasEnoughData {
                AppListCard(summary: summary, hoveredApp: $hoveredApp, pinnedApp: $pinnedApp)
            }
            FooterView()
        }
        .padding(12)
        .frame(width: Self.width)
        .animation(.smooth(duration: 0.25), value: range)
    }
}
