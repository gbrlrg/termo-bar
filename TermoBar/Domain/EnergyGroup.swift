import Foundation

/// App (ou processo solto) ao qual a energia de um processo é atribuída.
struct EnergyGroup: Hashable, Sendable {
    let id: String
    let name: String

    /// Processos cujo responsável não é um app comum, mas pertencem a um.
    static let aliases: [String: EnergyGroup] = [
        "SimulatorTrampoline": EnergyGroup(id: "com.apple.iphonesimulator", name: String(localized: "Simulador iOS")),
        "com.apple.CoreSimulator": EnergyGroup(
            id: "com.apple.iphonesimulator", name: String(localized: "Simulador iOS")),
        "com.docker.backend": EnergyGroup(id: "com.docker.docker", name: "Docker"),
    ]
    static let systemNames = ["kernel_task": "Kernel"]

    /// Grupo de um processo que não pertence a nenhum app aberto, pelo nome do executável.
    ///
    /// Sem nome (processos de outros usuários que o registro da GPU também não nomeia), vai para
    /// "Outros processos". Os conhecidos usam o id do app, para somar com ele quando estiver aberto.
    static func process(named name: String?) -> EnergyGroup {
        guard let name else {
            return EnergyGroup(id: AppID.unknownProcess, name: String(localized: "Outros processos"))
        }
        if let alias = aliases[name] ?? aliases.first(where: { name.hasPrefix($0.key) })?.value {
            return alias
        }
        return EnergyGroup(id: AppID.process(named: name), name: systemNames[name] ?? name)
    }
}
