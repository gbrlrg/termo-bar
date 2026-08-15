/// Nível de pressão térmica publicado pelo kernel; mais fino que `ProcessInfo.thermalState`.
enum ThermalPressure: Int, CaseIterable, Comparable, Sendable {
    case nominal, moderate, heavy, critical, sleeping

    /// A partir de "pesada" o macOS reduz a frequência do chip.
    var isThrottling: Bool { self >= .heavy }

    var label: String {
        switch self {
        case .nominal: "Normal"
        case .moderate: "Moderada"
        case .heavy: "Limitando desempenho"
        case .critical: "Crítica"
        case .sleeping: "Suspensão térmica"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
