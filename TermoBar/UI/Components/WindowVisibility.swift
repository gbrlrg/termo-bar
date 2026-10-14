import SwiftUI

extension View {
    /// Informa quando a janela que contém a view entra ou sai da tela (aberta ou fechada, não
    /// coberta por outras janelas). Começa como visível.
    ///
    /// O popover da barra de menus não é destruído ao fechar: a janela só sai da tela, e o
    /// conteúdo continuaria se redesenhando a cada leitura.
    func onWindowVisibilityChange(_ action: @escaping (Bool) -> Void) -> some View {
        background(WindowVisibilityReader(action: action))
    }
}

private struct WindowVisibilityReader: NSViewRepresentable {
    let action: (Bool) -> Void

    func makeNSView(context: Context) -> ObservingView {
        ObservingView(action: action)
    }

    func updateNSView(_ view: ObservingView, context: Context) {
        view.action = action
    }

    final class ObservingView: NSView {
        var action: (Bool) -> Void
        private var isVisible = true
        private var observation: NSKeyValueObservation?

        init(action: @escaping (Bool) -> Void) {
            self.action = action
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // `isVisible` muda na hora em que a janela entra ou sai da tela. A notificação de oclusão
            // não serve: não chega quando a tela está desligada nem para janelas já cobertas.
            observation = window?.observe(\.isVisible) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.update() }
            }
        }

        private func update() {
            guard let window else { return }
            let isVisible = window.isVisible
            guard isVisible != self.isVisible else { return }
            self.isVisible = isVisible
            // Fora do ciclo de atualização do SwiftUI, que não aceita mudar estado no meio dele.
            DispatchQueue.main.async { [action] in action(isVisible) }
        }
    }
}
