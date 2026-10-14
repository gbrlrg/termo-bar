import SwiftUI

/// Bloco com fundo arredondado que agrupa o conteúdo do popover.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Título de um card com um detalhe numérico à direita.
struct CardTitle: View {
    let title: LocalizedStringKey
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText())
        }
    }
}

/// Valor com legenda, alinhado à direita.
struct Stat: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.semibold)).monospacedDigit()
        }
    }
}
