/// Uma ventoinha: rotação atual e a faixa em que o sistema a controla (rpm).
struct Fan: Identifiable, Equatable, Sendable {
    /// Abaixo disso a ventoinha está parada; ao desligar, o SMC ainda informa algumas rpm por um instante.
    static let spinningThreshold = 100.0

    let id: Int
    let rpm: Double
    let minimum: Double
    let maximum: Double

    var isSpinning: Bool { rpm >= Self.spinningThreshold }
}
