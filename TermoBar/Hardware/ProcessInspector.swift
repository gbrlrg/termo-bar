import Foundation

/// Detalhes de um processo para a lista "Processos agora": o que é, de onde roda e desde quando.
struct ProcessDetails: Sendable {
    let pid: pid_t
    let description: ProcessDescription
    /// Linha de comando completa (dica ao passar o cursor).
    let commandLine: String?
    let startDate: Date?
}

/// Lê executável, argumentos e pasta de trabalho dos processos (libproc e sysctl).
///
/// Argumentos e pasta só são legíveis em processos do próprio usuário; os do sistema
/// aparecem apenas pelo nome.
enum ProcessInspector {
    /// Sem a barra final, como a pasta de trabalho é comparada.
    private static let home = URL.homeDirectory.path(percentEncoded: false).replacing(/\/$/, with: "")
    private static let simulatorDevices = URL.homeDirectory
        .appending(path: "Library/Developer/CoreSimulator/Devices")

    static func details(of pid: pid_t) -> ProcessDetails? {
        guard let info = bsdInfo(pid) else { return nil }
        let arguments = arguments(of: pid)
        let facts = ProcessFacts(
            name: name(of: pid) ?? "PID \(pid)",
            executablePath: executablePath(of: pid),
            arguments: arguments,
            workingDirectory: workingDirectory(of: pid))
        let start = info.pbi_start_tvsec > 0 ? Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec)) : nil
        return ProcessDetails(
            pid: pid,
            description: ProcessDescription(facts, homeDirectory: home, simulatorDevice: simulatorDeviceName),
            commandLine: arguments.isEmpty ? nil : arguments.joined(separator: " "),
            startDate: start)
    }

    /// Momento em que o processo começou; distingue um PID reaproveitado.
    static func startTime(of pid: pid_t) -> UInt64? {
        bsdInfo(pid).map { $0.pbi_start_tvsec &* 1_000_000 &+ $0.pbi_start_tvusec }
    }

    private static func bsdInfo(_ pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info : nil
    }

    private static func name(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(nullTerminated: buffer)
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(nullTerminated: buffer)
    }

    private static func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        return path.isEmpty ? nil : path
    }

    /// `argv` pelo `KERN_PROCARGS2`: argc, caminho do executável, preenchimento e os argumentos.
    private static func arguments(of pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        let argc = buffer.withUnsafeBytes { Int($0.loadUnaligned(as: Int32.self)) }
        let bytes = buffer.prefix(size).dropFirst(MemoryLayout<Int32>.size)

        // Pula o caminho do executável e os zeros que o seguem.
        var index = bytes.firstIndex(of: 0) ?? bytes.endIndex
        index = bytes[index...].firstIndex { $0 != 0 } ?? bytes.endIndex

        var arguments: [String] = []
        while arguments.count < argc, index < bytes.endIndex {
            let end = bytes[index...].firstIndex(of: 0) ?? bytes.endIndex
            arguments.append(String(decoding: bytes[index..<end], as: UTF8.self))
            index = end + 1
        }
        return arguments
    }

    private static func simulatorDeviceName(udid: String) -> String? {
        let plist = simulatorDevices.appending(path: udid).appending(path: "device.plist")
        guard let data = try? Data(contentsOf: plist),
            let properties = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return properties["name"] as? String
    }
}
