#if DEBUG
import SwiftUI

/// TERMOBAR_SNAPSHOT=<png> abre o popover numa janela comum e captura a tela dela
/// depois de TERMOBAR_SNAPSHOT_DELAY segundos (padrão 3). Só em Debug.
@MainActor
enum DebugSnapshot {
    static func runIfRequested(_ monitor: Monitor) {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["TERMOBAR_SNAPSHOT"] else { return }
        let delay = Double(env["TERMOBAR_SNAPSHOT_DELAY"] ?? "") ?? 3
        DispatchQueue.main.async {
            let popover = env["TERMOBAR_SETTINGS_TAB"] == nil
            let window = NSWindow(contentRect: .init(x: 200, y: 200, width: 480, height: 800),
                                  styleMask: popover ? [.borderless] : [.titled], backing: .buffered, defer: false)
            if popover {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
            if env["TERMOBAR_APPEARANCE"] == "dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
            if env["TERMOBAR_APPEARANCE"] == "light" { NSApp.appearance = NSAppearance(named: .aqua) }
            if let tab = env["TERMOBAR_SETTINGS_TAB"] {
                if tab == "sensores" { monitor.showAllSensors = true }
                window.contentView = NSHostingView(rootView: SettingsView(monitor: monitor, selection: tab))
            } else {
                window.contentView = NSHostingView(rootView: PopoverView(monitor: monitor)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous)))
            }
            window.setContentSize(window.contentView!.fittingSize)
            window.orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if let csv = env["TERMOBAR_EXPORT"] {
                    try? monitor.store.exportCSV(resolution: .raw, to: URL(fileURLWithPath: csv))
                }
                let capture = Process()
                capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l\(window.windowNumber)", path]
                try? capture.run()
                capture.waitUntilExit()
                exit(0)
            }
        }
    }
}
#endif
