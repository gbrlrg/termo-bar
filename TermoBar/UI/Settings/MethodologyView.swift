import SwiftUI

/// Como cada número é medido, dentro do app.
struct MethodologyView: View {
    private static let topics: [(title: String, text: String)] = [
        (
            "Temperatura",
            "Lida direto dos sensores do die do chip, a cada segundo, sem privilégio de administrador. Cada registro é a média das leituras do intervalo, o que tira o ruído sem esconder picos: o ponto mais quente é guardado à parte."
        ),
        (
            "Energia de CPU por app",
            "Contador de energia que o próprio kernel mantém para cada processo, em joules físicos — não é uma estimativa como o \"Impacto de Energia\" do Monitor de Atividade. Um núcleo de desempenho a 100% marca cerca de 6,5 W num M5."
        ),
        (
            "Energia de GPU por app",
            "A energia total da GPU, medida pelo chip, é dividida entre os processos na proporção do tempo de GPU que cada um usou no intervalo."
        ),
        (
            "Agrupamento",
            "Cada processo conta para o app responsável por ele, como no Monitor de Atividade: helpers do navegador vão para o navegador, compiladores lançados no terminal vão para o terminal."
        ),
        (
            "Limites",
            "A CPU de processos do sistema que rodam como administrador (como o kernel) não é legível sem privilégio e fica de fora. A GPU do WindowServer, que desenha a tela, entra na conta."
        ),
        (
            "Limitação térmica",
            "Vem da pressão térmica publicada pelo kernel. A partir do nível \"pesada\" o macOS reduz a frequência do chip; esses trechos aparecem destacados no gráfico."
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Self.topics, id: \.title) { topic in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.title).font(.headline)
                        Text(topic.text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
        .frame(minHeight: 380)
    }
}
