import Foundation

/// Detalhes de um processo para a lista "Processos agora": o que é, de onde roda e desde quando.
struct ProcessDetails: Sendable {
    let pid: pid_t
    let description: ProcessDescription
    /// Linha de comando completa (dica ao passar o cursor).
    let commandLine: String?
    let startDate: Date?
}

/// Um processo (ou vários iguais, como as abas do Chrome) de um app, com a potência recente.
struct LiveProcess: Identifiable {
    let description: ProcessDescription
    private(set) var pids: [pid_t] = []
    private(set) var power = Power.zero
    /// Só quando é um processo único.
    private(set) var details: ProcessDetails?

    var id: ProcessDescription { description }

    private init(description: ProcessDescription) {
        self.description = description
    }

    private mutating func add(_ details: ProcessDetails, power: Power) {
        pids.append(details.pid)
        self.power += power
        self.details = pids.count == 1 ? details : nil
    }

    /// Junta os processos iguais (mesmo nome e projeto) e ordena do que mais gasta para o que menos gasta.
    ///
    /// - Parameters:
    ///   - averages: potência recente de cada processo do app (`ProcessActivity.average(of:)`).
    ///   - fallbackName: nome do app, para os processos do sistema que não revelam detalhes.
    ///   - details: detalhes lidos do kernel; `nil` quando o processo não é legível.
    static func group(
        _ averages: [(pid: pid_t, power: Power)], fallbackName: String, details: (pid_t) -> ProcessDetails?
    ) -> [LiveProcess] {
        var groups: [ProcessDescription: LiveProcess] = [:]
        var order: [ProcessDescription] = []
        for (pid, power) in averages {
            // Processos do sistema não revelam detalhes; aparecem pelo nome do grupo.
            let process =
                details(pid)
                ?? ProcessDetails(
                    pid: pid,
                    description: ProcessDescription(
                        ProcessFacts(name: fallbackName, executablePath: nil, arguments: [], workingDirectory: nil),
                        homeDirectory: ""),
                    commandLine: nil, startDate: nil)
            let key = process.description
            if groups[key] == nil {
                order.append(key)
                groups[key] = LiveProcess(description: key)
            }
            groups[key]?.add(process, power: power)
        }
        return order.compactMap { groups[$0] }.sorted { $0.power.total > $1.power.total }
    }
}
