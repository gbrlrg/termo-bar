import Foundation

/// Rateio da potência da GPU entre os processos, a partir do tempo de GPU de cada um.
///
/// Fica fora do `GPUSampler`, que lê o IOReport e o IORegistry, para a conta poder ser testada.
struct GPUAttribution: Sendable {
    static let compositorName = "WindowServer"
    /// A parte do WindowServer, com disputa, fica limitada a este múltiplo da sua referência.
    static let compositorCapFactor = 1.5
    static let minimumCompositorCap = 0.1
    /// Abaixo desta ocupação somada dos outros processos, não há disputa pela GPU.
    static let contentionThreshold = 0.05
    /// Peso de cada nova medição na média móvel da referência do WindowServer.
    static let baselineSmoothing = 0.1
    static let nanosecondsPerSecond = 1e9

    /// Potência típica da GPU quando só o WindowServer a usa (W).
    private(set) var compositorBaseline = 0.3

    /// Fração do intervalo (0–1) em que cada processo ocupou a GPU, pelo tempo acumulado (ns).
    static func occupancy(
        times: [pid_t: UInt64], previous: [pid_t: UInt64], elapsed: TimeInterval
    ) -> [pid_t: Double] {
        guard elapsed > 0 else { return [:] }
        var occupancy: [pid_t: Double] = [:]
        for (pid, time) in times {
            // Processo que começou a usar a GPU neste intervalo (ou PID reaproveitado): todo o tempo dele é daqui.
            if let delta = CounterDelta.since(previous[pid], current: time) {
                occupancy[pid] = min(Double(delta) / nanosecondsPerSecond / elapsed, 1)
            }
        }
        return occupancy
    }

    /// Divide a potência da GPU pelos processos na proporção do tempo de GPU de cada um.
    ///
    /// O WindowServer é exceção: o tempo de GPU dele inclui a espera dos quadros na fila e
    /// infla quando outro processo ocupa a GPU, sem que ele gaste mais. Com disputa, ele fica
    /// com no máximo 1,5× a potência que a GPU tem quando só ele a usa, e o resto vai para
    /// quem disputa. Sem disputa, essa potência é aprendida como referência.
    mutating func attribute(_ watts: Double, occupancy: [pid_t: Double], names: [pid_t: String]) -> [pid_t: Double] {
        let busy = occupancy.values.reduce(0, +)
        guard busy > 0 else { return [:] }
        let proportional = occupancy.mapValues { watts * $0 / busy }
        guard let compositor = names.first(where: { $0.value == Self.compositorName })?.key,
            let compositorOccupancy = occupancy[compositor]
        else { return proportional }

        let others = busy - compositorOccupancy
        guard others >= Self.contentionThreshold else {
            compositorBaseline += (watts - compositorBaseline) * Self.baselineSmoothing
            return proportional
        }
        let cap = max(compositorBaseline * Self.compositorCapFactor, Self.minimumCompositorCap)
        let compositorWatts = min(proportional[compositor] ?? 0, cap)
        var result =
            occupancy
            .filter { $0.key != compositor }
            .mapValues { (watts - compositorWatts) * $0 / others }
        result[compositor] = compositorWatts
        return result
    }

    /// "pid 415, WindowServer" → (415, "WindowServer")
    static func parse(creator: String) -> (pid: pid_t, name: String)? {
        guard creator.hasPrefix("pid "), let comma = creator.firstIndex(of: ","),
            let pid = pid_t(creator.dropFirst(4).prefix { $0.isNumber })
        else { return nil }
        return (pid, creator[creator.index(after: comma)...].trimmingCharacters(in: .whitespaces))
    }
}

/// Diferença entre duas leituras de um contador acumulado do kernel (energia, tempo de GPU).
enum CounterDelta {
    /// Quanto o contador andou desde `previous`; `nil` se não andou.
    ///
    /// Sem leitura anterior, ou com uma maior que a atual (PID reaproveitado por outro processo),
    /// todo o valor atual conta como deste intervalo.
    static func since(_ previous: UInt64?, current: UInt64) -> UInt64? {
        let base = previous.flatMap { $0 <= current ? $0 : nil } ?? 0
        return current > base ? current - base : nil
    }
}
