import Foundation

/// Lê os sensores de temperatura da pastilha do SoC via IOHIDEventSystem (sem sudo).
final class TemperatureSensors {
    struct Sensor: Identifiable {
        let id: String
        let label: String
        let value: Double?
        /// Entrou na média? Fica de fora quando a leitura é implausível ou destoa das demais.
        let included: Bool
    }

    struct Reading {
        let average: Double
        let maximum: Double
        let sensors: [Sensor]
    }

    private static let temperatureEvent: Int64 = 15
    private static let plausible = 10.0...130.0
    /// Um sensor do die que destoa da mediana por mais que isso está com defeito ou é outro componente.
    private static let maxDeviation = 25.0

    private let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault)
    private var dieSensors: [(name: String, service: IOHIDServiceClient)] = []
    private var otherSensors: [(name: String, service: IOHIDServiceClient)] = []

    init() {
        loadSensors()
    }

    private func loadSensors() {
        _ = IOHIDEventSystemClientSetMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        guard let services = IOHIDEventSystemClientCopyServices(client) as? [AnyObject] else { return }
        var named: [(name: String, service: IOHIDServiceClient)] = []
        for object in services {
            let service = unsafeDowncast(object, to: IOHIDServiceClient.self)
            guard let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String else { continue }
            named.append((name, service))
        }
        named.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        // "PMU tdie*" são os sensores do die no M-series; se o chip usar outros nomes,
        // cai para qualquer sensor que não seja bateria ou SSD.
        let die = named.filter { $0.name.hasPrefix("PMU tdie") }
        let fallback = named.filter { !$0.name.contains("battery") && !$0.name.contains("NAND") }
        dieSensors = die.isEmpty ? fallback : die
        let dieNames = Set(dieSensors.map(\.name))
        otherSensors = named.filter { !dieNames.contains($0.name) }
    }

    private func value(of service: IOHIDServiceClient) -> Double? {
        guard let event = IOHIDServiceClientCopyEvent(service, Self.temperatureEvent, 0, 0) else { return nil }
        let value = IOHIDEventGetFloatValue(event, Int32(Self.temperatureEvent << 16))
        return Self.plausible.contains(value) ? value : nil
    }

    func read(includeOthers: Bool = false) -> Reading? {
        let values = dieSensors.map { value(of: $0.service) }
        let valid = values.compactMap { $0 }.sorted()
        guard !valid.isEmpty else { return nil }
        let median = valid[valid.count / 2]
        var accepted: [Double] = []
        var sensors: [Sensor] = []
        for (sensor, value) in zip(dieSensors, values) {
            let ok = value.map { abs($0 - median) <= Self.maxDeviation } ?? false
            if ok, let value { accepted.append(value) }
            sensors.append(Sensor(id: sensor.name, label: Self.label(for: sensor.name), value: value, included: ok))
        }
        if includeOthers {
            for sensor in otherSensors {
                sensors.append(Sensor(id: sensor.name, label: Self.label(for: sensor.name),
                                      value: value(of: sensor.service), included: false))
            }
        }
        guard let maximum = accepted.max() else { return nil }
        return Reading(average: accepted.reduce(0, +) / Double(accepted.count), maximum: maximum, sensors: sensors)
    }

    /// Nomes legíveis para os sensores do IOHID.
    static func label(for name: String) -> String {
        let number = name.drop { !$0.isNumber }
        switch true {
        case name.hasPrefix("PMU tdie"): return "Chip · sensor \(number)"
        case name.hasPrefix("PMU2 tdie"): return "Chip, controlador 2 · sensor \(number)"
        case name.hasPrefix("PMU tdev"): return "Placa · sensor \(number)"
        case name.hasPrefix("PMU2 tdev"): return "Placa, controlador 2 · sensor \(number)"
        case name.hasPrefix("als"): return "Sensor de luz ambiente"
        case name.contains("tcal"): return "Calibração \(name.hasPrefix("PMU2") ? "2" : "1")"
        case name.hasPrefix("NAND"): return "SSD"
        case name.contains("battery"): return "Bateria"
        default: return name
        }
    }
}
