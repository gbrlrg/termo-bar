import Foundation

/// Período exibido nos gráficos.
enum TimeRange: Int, CaseIterable, Identifiable, Sendable {
    case quarter = 900
    case hour = 3600
    case day = 86400
    case week = 604800

    var id: Self { self }

    var seconds: TimeInterval { TimeInterval(rawValue) }

    var label: String {
        switch self {
        case .quarter: "15 min"
        case .hour: "1 h"
        case .day: "24 h"
        case .week: String(localized: "7 dias")
        }
    }

    /// Largura de cada barra do gráfico de energia.
    var binSize: TimeInterval {
        switch self {
        case .quarter: 15
        case .hour: 60
        case .day: 15 * 60
        case .week: 3600
        }
    }

    /// Até 1 h usa as leituras finas; acima disso, os resumos por minuto.
    var usesMinuteSummaries: Bool { self == .day || self == .week }

    /// Início da barra que contém `date`.
    func bin(containing date: Date) -> Date {
        let start = (date.timeIntervalSinceReferenceDate / binSize).rounded(.down) * binSize
        return Date(timeIntervalSinceReferenceDate: start)
    }
}
