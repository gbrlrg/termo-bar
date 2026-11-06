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
    private var batterySensors: [Service] = []

    init() {
        loadSensors()
    }

    /// Lê os sensores do die e descarta os que destoam da mediana.
    /// - Parameter includeOthers: inclui na lista (fora da média) os sensores que não são do die.
    func read(includeOthers: Bool = false) -> Reading? {
        let values = dieSensors.map { value(of: $0.client) }
        guard let result = DieTemperatureFilter.filter(values) else { return nil }

        var sensors = zip(dieSensors, zip(values, result.isIncluded)).map { service, reading in
            Sensor(
                id: service.name, label: Self.label(for: service.name), value: reading.0, isOnDie: true,
                isIncluded: reading.1)
        }
        if includeOthers {
            sensors += otherSensors.map {
                Sensor(
                    id: $0.name, label: Self.label(for: $0.name), value: value(of: $0.client), isOnDie: false,
                    isIncluded: false)
            }
        }
        return Reading(average: result.average, maximum: result.maximum, sensors: sensors)
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
        batterySensors = otherSensors.filter { $0.name.contains("battery") }
    }

    /// Temperatura da bateria (a maior entre as células); `nil` em Macs sem bateria.
    func readBattery() -> Double? {
        batterySensors.compactMap { value(of: $0.client) }.max()
    }

    private func value(of service: IOHIDServiceClient) -> Double? {
        guard let event = IOHIDServiceClientCopyEvent(service, Self.temperatureEventType, 0, 0) else { return nil }
        let value = IOHIDEventGetFloatValue(event, Self.temperatureField)
        return DieTemperatureFilter.plausible(value)
    }

    /// Nome legível de um sensor do IOHID.
    static func label(for name: String) -> String { SensorLabel.label(for: name) }
}
