import AppKit

/// Mede a potência de cada app somando a energia de todos os processos pelos quais ele
/// é responsável (helpers, compiladores lançados pelo terminal etc.).
///
/// - CPU: contador de energia do kernel por processo (`ri_energy_nj`, nJ físicos).
/// - GPU: energia total da GPU rateada pelo tempo de GPU de cada processo.
///
/// A CPU de processos de outros usuários (root, WindowServer) não é legível sem privilégio.
final class EnergySampler {
    /// App (ou processo solto) ao qual a energia é atribuída.
    struct Group: Hashable, Sendable {
        let id: String
        let name: String
    }

    struct Measurement: Sendable {
        /// Potência média (W) de cada grupo desde a medição anterior.
        let byGroup: [Group: Power]
        /// Potência média de cada processo e o grupo a que ela foi somada.
        let byProcess: [ProcessActivity.Entry]
        /// Potência total da GPU (W).
        let gpuTotal: Double?
        /// Período coberto pela medição (s).
        let duration: TimeInterval
    }

    /// Processos cujo responsável não é um app comum, mas pertencem a um.
    private static let aliases: [String: Group] = [
        "SimulatorTrampoline": Group(id: "com.apple.iphonesimulator", name: "Simulador iOS"),
        "com.apple.CoreSimulator": Group(id: "com.apple.iphonesimulator", name: "Simulador iOS"),
        "com.docker.backend": Group(id: "com.docker.docker", name: "Docker"),
    ]
    private static let systemNames = ["kernel_task": "Kernel"]
    private static let nanojoulesPerJoule = 1e9

    private let gpu = GPUSampler()
    private var lastEnergy: [pid_t: UInt64] = [:]
    private var groups: [pid_t: Group] = [:]
    private var lastDate: Date?

    /// Potência desde a chamada anterior; `nil` na primeira, quando ainda não há com o que comparar.
    func sample() -> Measurement? {
        let now = Date()
        let gpuSample = gpu.sample()
        let pids = ProcessInfoReader.allPIDs()
        let isFirstSample = lastDate == nil

        var energy: [pid_t: UInt64] = [:]
        var joules: [pid_t: Double] = [:]
        for pid in pids {
            guard let total = ProcessInfoReader.cpuEnergy(of: pid) else { continue }
            energy[pid] = total
            guard !isFirstSample else { continue }
            // Processo novo (ou PID reaproveitado): toda a energia é deste intervalo.
            let previous = lastEnergy[pid].flatMap { $0 <= total ? $0 : nil } ?? 0
            guard total > previous else { continue }
            joules[pid] = Double(total - previous) / Self.nanojoulesPerJoule
        }

        let alive = Set(pids)
        groups = groups.filter { alive.contains($0.key) }
        lastEnergy = energy
        defer { lastDate = now }
        guard let lastDate else { return nil }
        let elapsed = now.timeIntervalSince(lastDate)
        guard elapsed > 0 else { return nil }

        var perProcess = joules.mapValues { Power(cpu: $0 / elapsed, gpu: 0) }
        for (pid, watts) in gpuSample?.perProcess ?? [:] where watts > 0 {
            perProcess[pid, default: .zero].gpu += watts
        }
        var byGroup: [Group: Power] = [:]
        var byProcess: [ProcessActivity.Entry] = []
        for (pid, power) in perProcess {
            let group = group(for: pid)
            byGroup[group, default: .zero] += power
            byProcess.append(.init(pid: pid, group: group.id, power: power))
        }
        return Measurement(byGroup: byGroup, byProcess: byProcess, gpuTotal: gpuSample?.total, duration: elapsed)
    }

    private func group(for pid: pid_t) -> Group {
        if let cached = groups[pid] { return cached }
        let responsible = responsibility_get_pid_responsible_for_pid(pid)
        let owner = responsible > 0 ? responsible : pid
        let group =
            Self.app(owner)
            ?? Self.app(ProcessInfoReader.parent(of: owner))
            ?? Self.processGroup(owner, fallbackName: gpu.clientNames[owner] ?? gpu.clientNames[pid])
        groups[pid] = group
        return group
    }

    private static func app(_ pid: pid_t) -> Group? {
        guard pid > 1, let app = NSRunningApplication(processIdentifier: pid),
            app.activationPolicy == .regular, let id = app.bundleIdentifier
        else { return nil }
        return Group(id: id, name: app.localizedName ?? id)
    }

    private static func processGroup(_ pid: pid_t, fallbackName: String?) -> Group {
        // Processos de outros usuários (WindowServer) não revelam o nome; o registro da GPU sim.
        guard let name = ProcessInfoReader.name(of: pid) ?? fallbackName else {
            return Group(id: AppID.unknownProcess, name: "Outros processos")
        }
        // Mesmo id do app, para somar com ele quando estiver aberto.
        if let alias = aliases[name] ?? aliases.first(where: { name.hasPrefix($0.key) })?.value {
            return alias
        }
        return Group(id: AppID.process(named: name), name: systemNames[name] ?? name)
    }
}

/// Consultas ao kernel sobre processos (libproc).
private enum ProcessInfoReader {
    /// Energia de CPU acumulada pelo processo (nJ); `nil` se o processo não é legível.
    static func cpuEnergy(of pid: pid_t) -> UInt64? {
        var info = rusage_info_v6()
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
            }
        }
        return status == 0 ? info.ri_energy_nj : nil
    }

    static func name(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(nullTerminated: buffer)
    }

    static func parent(of pid: pid_t) -> pid_t {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return 0 }
        return pid_t(info.pbi_ppid)
    }

    static func allPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        // Folga para processos criados entre as duas chamadas.
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        return Array(pids.prefix(Int(max(filled, 0))))
    }
}
