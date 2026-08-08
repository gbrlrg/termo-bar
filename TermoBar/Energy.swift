import AppKit

/// Potência de um app, separada em CPU e GPU.
struct Power: Codable, Hashable {
    var cpu: Double
    var gpu: Double
    var total: Double { cpu + gpu }

    static let zero = Power(cpu: 0, gpu: 0)
    static func + (a: Power, b: Power) -> Power { Power(cpu: a.cpu + b.cpu, gpu: a.gpu + b.gpu) }
    static func * (a: Power, k: Double) -> Power { Power(cpu: a.cpu * k, gpu: a.gpu * k) }
}

/// Mede a potência de cada app somando a energia de todos os processos pelos quais ele
/// é responsável (helpers, compiladores lançados pelo terminal etc.).
/// - CPU: contador de energia do kernel por processo (`ri_energy_nj`, nJ físicos).
/// - GPU: energia total da GPU rateada pelo tempo de GPU de cada processo.
/// A CPU de processos de outros usuários (root, WindowServer) não é legível sem privilégio.
final class EnergySampler {
    struct Group: Hashable {
        let id: String
        let name: String
    }

    struct Result {
        let byGroup: [Group: Power]
        let gpuTotal: Double?
    }

    // Processos cujo responsável não é um app comum, mas pertencem a um.
    private static let aliases: [String: (bundleID: String, name: String)] = [
        "SimulatorTrampoline": ("com.apple.iphonesimulator", "Simulador iOS"),
        "com.apple.CoreSimulator": ("com.apple.iphonesimulator", "Simulador iOS"),
        "com.docker.backend": ("com.docker.docker", "Docker"),
    ]
    private static let systemNames = [
        "WindowServer": "WindowServer",
        "kernel_task": "Kernel",
    ]

    private let gpu = GPUSampler()
    private var lastEnergy: [pid_t: UInt64] = [:]
    private var groups: [pid_t: Group] = [:]
    private var lastTime: Date?

    /// `nil` na primeira chamada, quando ainda não há leitura anterior para comparar.
    func sample() -> Result? {
        let now = Date()
        let gpuSample = gpu.sample()
        let pids = Self.allPIDs()
        var energy: [pid_t: UInt64] = [:]
        var joules: [Group: Double] = [:]

        for pid in pids {
            var info = rusage_info_v6()
            let ok = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V6, $0) == 0
                }
            }
            guard ok else { continue }
            let total = info.ri_energy_nj
            energy[pid] = total
            guard lastTime != nil else { continue }
            // Processo novo (ou PID reaproveitado): toda a energia é deste intervalo.
            let previous = lastEnergy[pid].flatMap { $0 <= total ? $0 : nil } ?? 0
            let delta = total - previous
            guard delta > 0 else { continue }
            joules[group(for: pid), default: 0] += Double(delta) / 1e9
        }

        let alive = Set(pids)
        groups = groups.filter { alive.contains($0.key) }
        lastEnergy = energy
        defer { lastTime = now }
        guard let lastTime else { return nil }
        let dt = now.timeIntervalSince(lastTime)
        guard dt > 0 else { return nil }

        var result = joules.mapValues { Power(cpu: $0 / dt, gpu: 0) }
        for (pid, watts) in gpuSample?.perProcess ?? [:] where watts > 0 {
            result[group(for: pid), default: .zero].gpu += watts
        }
        return Result(byGroup: result, gpuTotal: gpuSample?.total)
    }

    private func group(for pid: pid_t) -> Group {
        if let cached = groups[pid] { return cached }
        let responsible = responsibility_get_pid_responsible_for_pid(pid)
        let owner = responsible > 0 ? responsible : pid
        let group = Self.app(owner) ?? Self.app(Self.parent(of: owner))
            ?? Self.processGroup(owner, fallbackName: gpu.names[owner] ?? gpu.names[pid])
        groups[pid] = group
        return group
    }

    private static func app(_ pid: pid_t) -> Group? {
        guard pid > 1, let app = NSRunningApplication(processIdentifier: pid),
              app.activationPolicy == .regular, let id = app.bundleIdentifier else { return nil }
        return Group(id: id, name: app.localizedName ?? id)
    }

    private static func processGroup(_ pid: pid_t, fallbackName: String?) -> Group {
        // Processos de outros usuários (WindowServer) não revelam o nome; o registro da GPU sim.
        guard let name = processName(pid) ?? fallbackName else {
            return Group(id: "proc:?", name: "Outros processos")
        }
        let alias = aliases[name] ?? aliases.first { name.hasPrefix($0.key) }?.value
        if let alias {
            // Mesmo id do app, para somar com ele quando estiver aberto.
            return Group(id: alias.bundleID, name: alias.name)
        }
        return Group(id: "proc:\(name)", name: systemNames[name] ?? name)
    }

    private static func processName(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func parent(of pid: pid_t) -> pid_t {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return 0 }
        return pid_t(info.pbi_ppid)
    }

    private static func allPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        return Array(pids.prefix(Int(max(filled, 0))))
    }
}
