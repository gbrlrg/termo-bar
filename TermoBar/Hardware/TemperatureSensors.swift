import Foundation

/// Lê os sensores de temperatura da pastilha do SoC via IOHIDEventSystem (sem sudo).
final class TemperatureSensors {
    struct Sensor: Identifiable, Sendable {
        let id: String
        let label: String
        let value: Double?
        /// Sensor da pastilha do SoC, candidato à média do chip; os outros são da placa, bateria etc.
        let isOnDie: Bool
        /// Entrou na média? Fica de fora quando a leitura é implausível ou destoa das demais.
        let isIncluded: Bool
    }

    struct Reading: Sendable {
        let average: Double
        let maximum: Double
        let sensors: [Sensor]
    }

    /// Faixa de leitura plausível (°C); fora dela o sensor está com defeito ou desligado.
    static let plausibleRange = 10.0...130.0
    /// Um sensor do die que destoa da mediana por mais que isso (°C) está com defeito ou é outro componente.
    static let maxDeviation = 25.0

    private static let temperatureEventType: Int64 = 15
    private static let temperatureField = Int32(temperatureEventType << 16)
    /// Página e uso HID dos sensores de temperatura da Apple.
    private static let matching = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5]

    private struct Service {
        let name: String
        let client: IOHIDServiceClient
    }

    private let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault)
    private var dieSensors: [Service] = []
    private var otherSensors: [Service] = []

    init() {
        loadSensors()
    }

    /// Lê os sensores do die e descarta os que destoam da mediana.
    /// - Parameter includeOthers: inclui na lista (fora da média) os sensores que não são do die.
    func read(includeOthers: Bool = false) -> Reading? {
        let values = dieSensors.map { value(of: $0.client) }
        let valid = values.compactMap { $0 }.sorted()
        guard !valid.isEmpty else { return nil }
        let median = valid[valid.count / 2]

        var accepted: [Double] = []
        var sensors: [Sensor] = []
        for (service, value) in zip(dieSensors, values) {
            let isIncluded = value.map { abs($0 - median) <= Self.maxDeviation } ?? false
            if isIncluded, let value { accepted.append(value) }
            sensors.append(
                Sensor(
                    id: service.name, label: Self.label(for: service.name), value: value, isOnDie: true,
                    isIncluded: isIncluded))
        }
        if includeOthers {
            sensors += otherSensors.map {
                Sensor(
                    id: $0.name, label: Self.label(for: $0.name), value: value(of: $0.client), isOnDie: false,
                    isIncluded: false)
            }
        }

        guard let maximum = accepted.max() else { return nil }
        return Reading(average: accepted.reduce(0, +) / Double(accepted.count), maximum: maximum, sensors: sensors)
    }

    private func loadSensors() {
        _ = IOHIDEventSystemClientSetMatching(client, Self.matching as CFDictionary)
        guard let objects = IOHIDEventSystemClientCopyServices(client) as? [AnyObject] else { return }
        let services =
            objects
            .compactMap { object -> Service? in
                let client = unsafeDowncast(object, to: IOHIDServiceClient.self)
                guard let name = IOHIDServiceClientCopyProperty(client, "Product" as CFString) as? String else {
                    return nil
                }
                return Service(name: name, client: client)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        // "PMU tdie*" são os sensores do die no M-series; se o chip usar outros nomes,
        // cai para qualquer sensor que não seja bateria ou SSD.
        let die = services.filter { $0.name.hasPrefix("PMU tdie") }
        let fallback = services.filter { !$0.name.contains("battery") && !$0.name.contains("NAND") }
        dieSensors = die.isEmpty ? fallback : die
        let dieNames = Set(dieSensors.map(\.name))
        otherSensors = services.filter { !dieNames.contains($0.name) }
    }

    private func value(of service: IOHIDServiceClient) -> Double? {
        guard let event = IOHIDServiceClientCopyEvent(service, Self.temperatureEventType, 0, 0) else { return nil }
        let value = IOHIDEventGetFloatValue(event, Self.temperatureField)
        return Self.plausibleRange.contains(value) ? value : nil
    }

    /// Nome legível de um sensor do IOHID.
    static func label(for name: String) -> String {
        let number = String(name.drop { !$0.isNumber })
        return switch true {
        case name.hasPrefix("PMU tdie"): String(localized: "Chip · sensor \(number)")
        case name.hasPrefix("PMU2 tdie"): String(localized: "Chip, controlador 2 · sensor \(number)")
        case name.hasPrefix("PMU tdev"): String(localized: "Placa · sensor \(number)")
        case name.hasPrefix("PMU2 tdev"): String(localized: "Placa, controlador 2 · sensor \(number)")
        case name.hasPrefix("als"): String(localized: "Sensor de luz ambiente")
        case name.contains("tcal"): String(localized: "Calibração \(name.hasPrefix("PMU2") ? "2" : "1")")
        case name.hasPrefix("NAND"): "SSD"
        case name.contains("battery"): String(localized: "Bateria")
        default: name
        }
    }
}
