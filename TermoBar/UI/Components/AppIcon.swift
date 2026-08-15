import SwiftUI

/// Ícone do app, ou um símbolo genérico para processos sem app.
struct AppIcon: View {
    let id: String

    var body: some View {
        if let image = AppIconCache.icon(for: id) {
            Image(nsImage: image).resizable().frame(width: 24, height: 24)
        } else {
            Image(systemName: AppIconCache.fallbackSymbol(for: id))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .padding(1)
        }
    }
}

@MainActor
private enum AppIconCache {
    private static var icons: [String: NSImage] = [:]
    /// Grupos sem app instalado (ex.: simuladores rodando sem o Simulator.app).
    private static let symbols = ["com.apple.iphonesimulator": "iphone"]
    /// Apps fora das pastas que o LaunchServices indexa.
    private static let knownPaths = [
        "com.apple.iphonesimulator": "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"
    ]

    static func fallbackSymbol(for id: String) -> String {
        symbols[id] ?? "gearshape.fill"
    }

    static func icon(for id: String) -> NSImage? {
        if let cached = icons[id] { return cached }
        guard !AppID.isProcess(id) else { return nil }
        let url =
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            ?? knownPaths[id].map { URL(filePath: $0) }
        guard let url, FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        icons[id] = image
        return image
    }
}
