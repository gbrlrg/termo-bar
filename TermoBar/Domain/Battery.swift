import Foundation

/// Estado da bateria interna, lido das propriedades do `AppleSmartBattery` (IORegistry).
struct BatteryStatus: Equatable, Sendable {
    /// Carga atual (0–100).
    var percent: Int
    var isPluggedIn: Bool
    var isCharging: Bool
    var cycleCount: Int?
    /// Capacidade de projeto, quando a bateria era nova (mAh).
    var designCapacity: Double?
    /// Capacidade máxima atual, a base da "Capacidade Máxima" dos Ajustes do Sistema (mAh).
    var nominalCapacity: Double?
    /// Carga que cabe agora na bateria cheia (mAh).
    var fullChargeCapacity: Double?
    /// Carga que ainda resta (mAh).
    var remainingCapacity: Double?
    /// Tensão da bateria (V).
    var voltage: Double
    /// Potência que sai da bateria agora (W); `nil` sem descarga.
    var dischargeWatts: Double?
    /// Tempo para completar a carga, estimado pelo macOS; só enquanto carrega.
    var minutesToFull: Int?

    /// Valor com que o macOS marca "ainda calculando".
    private static let unknownMinutes = 65535

    /// Cria o estado a partir das propriedades do serviço; `nil` se não for uma bateria legível.
    ///
    /// Os Macs mais novos guardam as capacidades dentro de `BatteryData`; os mais antigos, na raiz.
    init?(properties: [String: Any]) {
        guard Self.bool(properties["BatteryInstalled"]) != false,
            let current = Self.number(properties["CurrentCapacity"]),
            let maximum = Self.number(properties["MaxCapacity"]), maximum > 0
        else { return nil }
        let data = properties["BatteryData"] as? [String: Any] ?? [:]
        func capacity(_ keys: (root: String, data: String)) -> Double? {
            (Self.number(data[keys.data]) ?? Self.number(properties[keys.root])).flatMap { $0 > 0 ? $0 : nil }
        }

        percent = Int((current / maximum * 100).rounded()).clamped(to: 0...100)
        isPluggedIn = Self.bool(properties["ExternalConnected"]) ?? false
        isCharging = Self.bool(properties["IsCharging"]) ?? false
        cycleCount = Self.number(properties["CycleCount"]).map { Int($0) }
        designCapacity = capacity(("DesignCapacity", "DesignCapacity"))
        nominalCapacity = capacity(("AppleRawMaxCapacity", "NominalChargeCapacity"))
        fullChargeCapacity = capacity(("AppleRawMaxCapacity", "FullChargeCapacity"))
        remainingCapacity = capacity(("AppleRawCurrentCapacity", "RemainingCapacity"))
        let millivolts = Self.number(properties["Voltage"]) ?? 0
        voltage = millivolts / 1000

        // Negativa quando descarrega; o registro a guarda como inteiro sem sinal.
        let milliamps = Self.integer(properties["Amperage"]).map(Double.init) ?? 0
        dischargeWatts = milliamps < 0 && voltage > 0 ? -milliamps * voltage / 1000 : nil

        let minutes = Self.number(properties["AvgTimeToFull"]).map { Int($0) }
        minutesToFull = isCharging ? minutes.flatMap { $0 == Self.unknownMinutes ? nil : $0 } : nil
    }

    /// Fração da capacidade de projeto que a bateria ainda guarda (0–1), como nos Ajustes do Sistema.
    var health: Double? {
        guard let nominalCapacity, let designCapacity else { return nil }
        return min(1, nominalCapacity / designCapacity)
    }

    /// Energia que resta na bateria (Wh).
    var remainingEnergy: Double? {
        remainingCapacity.flatMap { energy(milliampHours: $0) }
    }

    /// Energia da bateria cheia (Wh).
    var fullEnergy: Double? {
        fullChargeCapacity.flatMap { energy(milliampHours: $0) }
    }

    /// Está gastando a bateria: fora da tomada e com corrente saindo.
    var isDischarging: Bool { !isPluggedIn && dischargeWatts != nil }

    private func energy(milliampHours: Double) -> Double? {
        voltage > 0 ? milliampHours / 1000 * voltage : nil
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber).map { $0.doubleValue }
    }

    private static func integer(_ value: Any?) -> Int64? {
        (value as? NSNumber).map { $0.int64Value }
    }

    private static func bool(_ value: Any?) -> Bool? {
        value as? Bool
    }
}

/// Quanto da bateria um consumo equivale por hora.
enum BatteryDrain {
    /// Percentual da bateria cheia gasto em uma hora a essa potência; `nil` sem a capacidade.
    static func percentPerHour(watts: Double, fullEnergy: Double?) -> Double? {
        guard let fullEnergy, fullEnergy > 0, watts >= 0 else { return nil }
        return watts / fullEnergy * 100
    }
}
