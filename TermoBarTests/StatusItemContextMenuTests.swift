import AppKit
import Testing

@MainActor
struct StatusItemContextMenuTests {
    @MainActor
    private final class Recorder {
        var calls: [String] = []

        var actions: StatusItemContextMenu.Actions {
            .init(
                openSettings: { self.calls.append("settings") },
                openActivityMonitor: { self.calls.append("activity") },
                checkForUpdates: { self.calls.append("updates") },
                toggleLaunchAtLogin: { self.calls.append("login") },
                quit: { self.calls.append("quit") })
        }
    }

    private func makeMenu(_ recorder: Recorder, launchAtLogin: Bool = false) -> NSMenu {
        StatusItemContextMenu.makeMenu(actions: recorder.actions, isLaunchAtLoginEnabled: launchAtLogin)
    }

    private func perform(_ item: NSMenuItem) {
        guard let action = item.action else { return }
        _ = item.target?.perform(action, with: item)
    }

    @Test func listsTheQuickActionsInOrder() {
        let menu = makeMenu(Recorder())
        let titles = menu.items.map { $0.isSeparatorItem ? "-" : $0.title }
        #expect(
            titles == [
                String(localized: "Ajustes…"), String(localized: "Monitor de Atividade"), "-",
                String(localized: "Buscar Atualizações…"), String(localized: "Abrir no início da sessão"), "-",
                String(localized: "Encerrar TermoBar"),
            ])
    }

    @Test func itemsRunTheirActions() {
        let recorder = Recorder()
        let menu = makeMenu(recorder)
        for item in menu.items where !item.isSeparatorItem { perform(item) }
        #expect(recorder.calls == ["settings", "activity", "updates", "login", "quit"])
    }

    @Test func settingsAndQuitKeepTheirShortcuts() {
        let menu = makeMenu(Recorder())
        #expect(menu.items.first?.keyEquivalent == ",")
        #expect(menu.items.last?.keyEquivalent == "q")
    }

    @Test(arguments: [true, false])
    func launchAtLoginItemReflectsTheCurrentState(isEnabled: Bool) {
        let menu = makeMenu(Recorder(), launchAtLogin: isEnabled)
        let item = menu.items.first { $0.title == String(localized: "Abrir no início da sessão") }
        #expect(item?.state == (isEnabled ? .on : .off))
    }

    @Test func onlyStatusBarWindowsOpenTheMenu() {
        let statusItem = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        statusItem.level = .statusBar
        let popover = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        popover.level = .popUpMenu

        #expect(StatusItemContextMenu.isStatusItemWindow(statusItem))
        #expect(!StatusItemContextMenu.isStatusItemWindow(popover))
        #expect(!StatusItemContextMenu.isStatusItemWindow(nil))
    }
}
