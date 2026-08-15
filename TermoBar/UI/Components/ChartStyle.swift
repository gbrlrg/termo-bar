import Charts
import SwiftUI

/// Peças visuais comuns aos gráficos do popover.
@MainActor
enum ChartStyle {
    /// Eixo Y discreto: grade fina e rótulos terciários à direita.
    static func quietYAxis(_ label: @escaping (Double) -> String) -> some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color(nsColor: .separatorColor))
            AxisValueLabel {
                if let number = value.as(Double.self) { Text(label(number)) }
            }
            .font(.caption2)
            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
        }
    }

    /// Linha vertical que marca o instante sob o cursor.
    static func hoverRule(at date: Date) -> some ChartContent {
        RuleMark(x: .value("Hora", date))
            .foregroundStyle(.secondary.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1))
    }
}
