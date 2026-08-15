/// Potência (W) ou energia (J), separada em CPU e GPU.
struct Power: Hashable, Sendable {
    var cpu: Double
    var gpu: Double

    var total: Double { cpu + gpu }

    static let zero = Power(cpu: 0, gpu: 0)

    static func + (lhs: Power, rhs: Power) -> Power {
        Power(cpu: lhs.cpu + rhs.cpu, gpu: lhs.gpu + rhs.gpu)
    }

    static func += (lhs: inout Power, rhs: Power) {
        lhs = lhs + rhs
    }

    static func * (lhs: Power, factor: Double) -> Power {
        Power(cpu: lhs.cpu * factor, gpu: lhs.gpu * factor)
    }

    static func / (lhs: Power, divisor: Double) -> Power {
        Power(cpu: lhs.cpu / divisor, gpu: lhs.gpu / divisor)
    }
}
