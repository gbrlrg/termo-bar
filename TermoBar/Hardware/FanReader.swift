import Foundation
import IOKit

/// Lê a rotação das ventoinhas no controlador do sistema (SMC), sem privilégio de administrador.
///
/// Macs sem ventoinha, como o MacBook Air, informam zero ventoinhas e a leitura volta vazia.
final class FanReader {
    /// Método do user client do AppleSMC que lê e descreve chaves.
    private static let structMethod: UInt32 = 2
    private static let readValue: UInt8 = 5
    private static let readInfo: UInt8 = 9

    private struct Key {
        let code: UInt32
        let info: SMCKeyInfo
    }

    private struct Slot {
        let id: Int
        let speed: Key
        let minimum: Double
        let maximum: Double
    }

    private var connection: io_connect_t = 0
    private var slots: [Slot] = []

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else {
            connection = 0
            return
        }
        let count = key("FNum").flatMap(value(of:)) ?? 0
        // Mínimo e máximo não mudam; só a rotação é lida a cada vez.
        slots = (0..<max(Int(count), 0)).compactMap { index in
            guard let speed = key("F\(index)Ac") else { return nil }
            return Slot(
                id: index, speed: speed,
                minimum: key("F\(index)Mn").flatMap(value(of:)) ?? 0,
                maximum: key("F\(index)Mx").flatMap(value(of:)) ?? 0)
        }
        if slots.isEmpty { close() }
    }

    deinit {
        close()
    }

    var hasFans: Bool { !slots.isEmpty }

    /// Rotação atual de cada ventoinha.
    func read() -> [Fan] {
        slots.compactMap { slot in
            value(of: slot.speed).map {
                Fan(id: slot.id, rpm: max($0, 0), minimum: slot.minimum, maximum: slot.maximum)
            }
        }
    }

    private func close() {
        guard connection != 0 else { return }
        IOServiceClose(connection)
        connection = 0
    }

    /// Tipo e tamanho de uma chave; `nil` se o SMC não a conhece.
    private func key(_ name: String) -> Key? {
        let code = SMCValue.fourCC(name)
        var input = SMCKeyData()
        input.key = code
        input.data8 = Self.readInfo
        return call(input).map { Key(code: code, info: $0.keyInfo) }
    }

    private func value(of key: Key) -> Double? {
        var input = SMCKeyData()
        input.key = key.code
        input.keyInfo = key.info
        input.data8 = Self.readValue
        guard let output = call(input) else { return nil }
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(key.info.dataSize))) }
        return SMCValue.decode(bytes, type: key.info.dataType)
    }

    private func call(_ input: SMCKeyData) -> SMCKeyData? {
        guard connection != 0 else { return nil }
        var input = input
        var output = SMCKeyData()
        var size = MemoryLayout<SMCKeyData>.stride
        let status = IOConnectCallStructMethod(
            connection, Self.structMethod, &input, MemoryLayout<SMCKeyData>.stride, &output, &size)
        return status == KERN_SUCCESS && output.result == 0 ? output : nil
    }
}
