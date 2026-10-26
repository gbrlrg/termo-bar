import AppKit

/// Menu de atalhos que abre com o botão direito (ou dois dedos) no item da barra de menus.
///
/// O `MenuBarExtra` em estilo janela só abre o popover e não expõe o clique direito; por isso o
/// evento é interceptado aqui, antes de chegar à janela do item.
@MainActor
final class StatusItemContextMenu {
    /// Ações que o menu dispara; ficam fora da classe para o menu poder ser montado nos testes.
    struct Actions {
        var openSettings: @MainActor () -> Void
        var openActivityMonitor: @MainActor () -> Void
        var checkForUpdates: @MainActor () -> Void
        var toggleLaunchAtLogin: @MainActor () -> Void
        var quit: @MainActor () -> Void
    }

    private let actions: Actions
    private let isLaunchAtLoginEnabled: @MainActor () -> Bool
    private var eventMonitor: Any?

    init(actions: Actions, isLaunchAtLoginEnabled: @escaping @MainActor () -> Bool) {
        self.actions = actions
        self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
    }

    /// Passa a interceptar o clique direito no item da barra. Chamar de novo não faz nada.
    func install() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self, Self.isStatusItemWindow(event.window), let view = event.window?.contentView else {
                return event
            }
            let menu = Self.makeMenu(actions: actions, isLaunchAtLoginEnabled: isLaunchAtLoginEnabled())
            NSMenu.popUpContextMenu(menu, with: event, for: view)
            return nil
        }
    }

    /// A janela do botão na barra de menus fica no nível próprio das janelas de itens de status.
    static func isStatusItemWindow(_ window: NSWindow?) -> Bool {
        window?.level == .statusBar
    }

    static func makeMenu(actions: Actions, isLaunchAtLoginEnabled: Bool) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ActionMenuItem(title: String(localized: "Ajustes…"), key: ",", action: actions.openSettings))
        menu.addItem(
            ActionMenuItem(title: String(localized: "Monitor de Atividade"), action: actions.openActivityMonitor))
        menu.addItem(.separator())
        menu.addItem(
            ActionMenuItem(title: String(localized: "Buscar Atualizações…"), action: actions.checkForUpdates))
        let login = ActionMenuItem(
            title: String(localized: "Abrir no início da sessão"), action: actions.toggleLaunchAtLogin)
        login.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: String(localized: "Encerrar TermoBar"), key: "q", action: actions.quit))
        return menu
    }
}

/// Item de menu que executa um closure, sem precisar de um alvo com seletores.
@MainActor
private final class ActionMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, key: String = "", action handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) não é usado") }

    @objc private func fire() { handler() }
}
