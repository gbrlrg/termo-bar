import IOKit

/// Lê a bateria interna do IORegistry, sem privilégio de administrador.
enum BatteryReader {
    /// `nil` em Macs sem bateria (mesa).
    static func read() -> BatteryStatus? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
            let dictionary = properties?.takeRetainedValue() as? [String: Any]
        else { return nil }
        return BatteryStatus(properties: dictionary)
    }
}
