import Foundation
import WidgetKit

/// Grava o resumo para o widget a cada registro e pede ao WidgetKit para redesenhá-lo quando algo mudou.
///
/// O macOS limita quantas vezes por dia um widget é redesenhado; pedir mais que isso não adianta.
/// Por isso o pedido só sai quando a mudança é visível, e no máximo uma vez por minuto.
@MainActor
final class WidgetPublisher {
    private static let minimumReloadInterval: TimeInterval = 60
    /// Diferença de temperatura (°C) que justifica redesenhar o widget.
    private static let temperatureStep = 1.0

    private var lastReload: (date: Date, snapshot: WidgetSnapshot)?
    /// Sem acesso ao App Group (build sem a assinatura do time), desiste depois do primeiro erro.
    private var isUnavailable = false

    func publish(_ snapshot: WidgetSnapshot) {
        guard !isUnavailable else { return }
        do {
            try snapshot.save()
        } catch {
            isUnavailable = true
            Log.system.error("Resumo do widget não gravado: \(String(describing: error), privacy: .public)")
            return
        }
        if let last = lastReload {
            guard snapshot.date.timeIntervalSince(last.date) >= Self.minimumReloadInterval else { return }
            let changed =
                abs(snapshot.celsius - last.snapshot.celsius) >= Self.temperatureStep
                || snapshot.pressure != last.snapshot.pressure
                || snapshot.apps.first?.id != last.snapshot.apps.first?.id
            guard changed else { return }
        }
        lastReload = (snapshot.date, snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.kind)
    }
}
