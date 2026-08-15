import Foundation

/// Lê a pressão térmica que o kernel publica via notify(3).
final class ThermalPressureReader {
    private static let notificationName = "com.apple.system.thermalpressurelevel"

    private let token: Int32?

    init() {
        var token: Int32 = 0
        let status = notify_register_check(Self.notificationName, &token)
        self.token = status == UInt32(NOTIFY_STATUS_OK) ? token : nil
    }

    deinit {
        if let token { notify_cancel(token) }
    }

    /// Nível atual; `.nominal` se o kernel não informar.
    func read() -> ThermalPressure {
        guard let token else { return .nominal }
        var state: UInt64 = 0
        guard notify_get_state(token, &state) == UInt32(NOTIFY_STATUS_OK) else { return .nominal }
        return Int(exactly: state).flatMap(ThermalPressure.init(rawValue:)) ?? .nominal
    }
}
