import Foundation

enum SystemInfo {
    /// Nome comercial do chip, como "Apple M5".
    static let chipName: String = string(sysctl: "machdep.cpu.brand_string") ?? "Apple Silicon"

    private static func string(sysctl name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(nullTerminated: buffer)
    }
}
