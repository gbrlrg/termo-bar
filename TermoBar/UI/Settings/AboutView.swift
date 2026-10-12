import SwiftUI

/// Ícone, versão e informações para suporte, como na aba Sobre de apps independentes para Mac.
struct AboutView: View {
    private static let website = URL(string: "https://github.com/gbrlrg/termo-bar")

    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("TermoBar").font(.system(size: 28, weight: .bold))
                Text("Versão \(Self.version) (\(Self.build))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .textSelection(.enabled)
            }

            Text("Temperatura do chip e energia por app, direto na barra de menus.")
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                if let website = Self.website {
                    Button("GitHub") { NSWorkspace.shared.open(website) }
                }
                Button(didCopy ? "Copiado" : "Copiar informações do sistema", action: copySystemInfo)
                    .help("Versão do app, do macOS e o chip, para pedidos de suporte")
            }

            Divider().padding(.vertical, 4)

            VStack(spacing: 6) {
                Label("Tudo fica neste Mac: o TermoBar não coleta nem envia dados.", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                if let copyright = Self.copyright {
                    Text(copyright).foregroundStyle(.tertiary)
                }
            }
            .font(.callout)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private func copySystemInfo() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.systemInfo, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            didCopy = false
        }
    }

    private static func info(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    private static let version = info("CFBundleShortVersionString") ?? "?"
    private static let build = info("CFBundleVersion") ?? "?"
    private static let copyright = info("NSHumanReadableCopyright")

    private static var systemInfo: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let patch = os.patchVersion > 0 ? ".\(os.patchVersion)" : ""
        return """
            TermoBar \(version) (\(build))
            macOS \(os.majorVersion).\(os.minorVersion)\(patch)
            \(SystemInfo.chipName)
            """
    }
}
