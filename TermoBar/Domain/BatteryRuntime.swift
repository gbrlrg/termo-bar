import Foundation

/// Autonomia estimada no ritmo de consumo recente.
struct RuntimeEstimate: Equatable, Sendable {
    /// Horas até a bateria acabar, se o consumo continuar como o medido.
    let hours: Double
    /// Potência média usada na conta (W).
    let watts: Double
    /// Quanto tempo de medição sustenta a média (s).
    let basis: TimeInterval

    /// Acima disso a estimativa deixa de ser informativa e vira "mais de 24 h".
    static let displayLimit: TimeInterval = 24 * 3600

    /// Minutos arredondados, para não passar precisão que a medição não tem: de 5 em 5 abaixo de
    /// uma hora e de 10 em 10 acima.
    var roundedMinutes: Int {
        let minutes = hours * 60
        let step = minutes < 60 ? 5.0 : 10.0
        return Int((minutes / step).rounded() * step)
    }

    var exceedsDisplayLimit: Bool { hours * 3600 > Self.displayLimit }
}

/// Potência de descarga recente, para estimar quanto a bateria ainda dura.
///
/// A potência instantânea oscila muito; a estimativa usa a média dos últimos minutos e só aparece
/// depois de medir tempo suficiente. Ligar na tomada ou dormir zera a medição, porque o consumo
/// de antes não diz nada sobre o de depois.
struct DischargeHistory: Sendable {
    /// Quanto do passado entra na média.
    static let window: TimeInterval = 600
    /// Medição mínima para estimar.
    static let minimumCoverage: TimeInterval = 180
    /// Intervalo sem leituras (suspensão, por exemplo) que descarta o que veio antes.
    static let maximumGap: TimeInterval = 60
    /// Abaixo disso a média é ruído e a conta daria dias.
    static let minimumWatts = 0.3

    private var points: [(date: Date, watts: Double)] = []

    /// Registra a leitura; sem descarga, esquece o histórico.
    mutating func record(_ status: BatteryStatus?, at date: Date) {
        guard let status, status.isDischarging, let watts = status.dischargeWatts else {
            points.removeAll()
            return
        }
        if let last = points.last, date.timeIntervalSince(last.date) > Self.maximumGap { points.removeAll() }
        points.append((date, watts))
        points.removeAll { date.timeIntervalSince($0.date) > Self.window }
    }

    /// Estimativa para o estado atual; `nil` enquanto faltar medição ou a conta não fizer sentido.
    func estimate(for status: BatteryStatus?) -> RuntimeEstimate? {
        guard let status, status.isDischarging, let remaining = status.remainingEnergy,
            let first = points.first, let last = points.last
        else { return nil }
        let basis = last.date.timeIntervalSince(first.date)
        guard basis >= Self.minimumCoverage else { return nil }
        let watts = points.reduce(0) { $0 + $1.watts } / Double(points.count)
        guard watts >= Self.minimumWatts else { return nil }
        return RuntimeEstimate(hours: remaining / watts, watts: watts, basis: basis)
    }
}
