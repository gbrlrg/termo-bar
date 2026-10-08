#if DEBUG
    import SwiftUI

    /// Captura de tela para documentação, controlada por variáveis de ambiente (só em Debug):
    ///
    /// - `TERMOBAR_SNAPSHOT=<png>`: abre o popover numa janela comum e salva uma captura dela.
    /// - `TERMOBAR_SNAPSHOT_DELAY=<s>`: espera antes da captura (padrão 3 s).
    /// - `TERMOBAR_SETTINGS_TAB=<aba>`: captura uma aba dos Ajustes em vez do popover.
    /// - `TERMOBAR_APPEARANCE=light|dark`: força o tema.
    /// - `TERMOBAR_EXPORT=<csv>`: exporta as leituras das últimas 24 h antes de sair.
    @MainActor
    enum DebugSnapshot {
        private static let defaultDelay: TimeInterval = 3

        static func runIfRequested() {
            let environment = ProcessInfo.processInfo.environment
            guard let path = environment["TERMOBAR_SNAPSHOT"] else { return }
            let delay = environment["TERMOBAR_SNAPSHOT_DELAY"].flatMap { TimeInterval($0) } ?? defaultDelay
            let settingsTab = environment["TERMOBAR_SETTINGS_TAB"].flatMap(SettingsTab.init(rawValue:))

            DispatchQueue.main.async {
                applyAppearance(environment["TERMOBAR_APPEARANCE"])
                let window = makeWindow(settingsTab: settingsTab)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if let csv = environment["TERMOBAR_EXPORT"] {
                        try? AppDependencies.monitor.exportCSV(resolution: .raw, to: URL(filePath: csv))
                    }
                    capture(window, to: path)
                    exit(0)
                }
            }
        }

        private static func applyAppearance(_ name: String?) {
            switch name {
            case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            case "light": NSApp.appearance = NSAppearance(named: .aqua)
            default: break
            }
        }

        private static func makeWindow(settingsTab: SettingsTab?) -> NSWindow {
            let window = NSWindow(
                contentRect: NSRect(x: 200, y: 200, width: 480, height: 800),
                styleMask: [.borderless], backing: .buffered, defer: false)
            let content: NSView
            if let settingsTab {
                // Só o conteúdo da aba: fora da cena Settings, a barra de abas não teria onde aparecer.
                if settingsTab == .sensors { AppDependencies.monitor.showAllSensors = true }
                content = NSHostingView(
                    rootView: settingsTab.content
                        .frame(width: SettingsView.width)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .appDependencies())
            } else {
                window.isOpaque = false
                window.backgroundColor = .clear
                content = NSHostingView(
                    rootView: PopoverView()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .appDependencies())
            }
            window.contentView = content
            window.setContentSize(content.fittingSize)
            window.orderFrontRegardless()
            return window
        }

        private static func capture(_ window: NSWindow, to path: String) {
            let screencapture = Process()
            screencapture.executableURL = URL(filePath: "/usr/sbin/screencapture")
            screencapture.arguments = ["-x", "-o", "-l\(window.windowNumber)", path]
            try? screencapture.run()
            screencapture.waitUntilExit()
        }
    }
#endif
