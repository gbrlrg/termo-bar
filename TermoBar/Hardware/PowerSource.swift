import IOKit.ps

/// Estado da fonte de energia interna (bateria), lido do IOPowerSources.
enum PowerSource {
    /// A bateria está recebendo carga agora.
    static func isCharging() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }
        return sources.contains { source in
            let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
            return description?[kIOPSIsChargingKey] as? Bool == true
        }
    }
}
