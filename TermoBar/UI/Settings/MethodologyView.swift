import SwiftUI

/// Como cada número é medido, dentro do app.
struct MethodologyView: View {
    private static let topics: [(title: LocalizedStringResource, symbol: String, text: LocalizedStringResource)] = [
        (
            "Temperatura", "thermometer.medium",
            "Lida direto dos sensores do die do chip, a cada segundo, sem privilégio de administrador. Cada registro é a média das leituras do intervalo, o que tira o ruído sem esconder picos: o ponto mais quente é guardado à parte."
        ),
        (
            "Energia de CPU por app", "cpu",
            "Contador de energia que o próprio kernel mantém para cada processo, em joules físicos — não é uma estimativa como o “Impacto de Energia” do Monitor de Atividade. Um núcleo de desempenho a 100% marca cerca de 6,5 W num M5."
        ),
        (
            "Energia de GPU por app", "square.3.layers.3d",
            "A energia total da GPU, medida pelo chip, é dividida entre os processos na proporção do tempo de GPU que cada um usou no intervalo."
        ),
        (
            "Agrupamento", "rectangle.3.group",
            "Cada processo conta para o app responsável por ele, como no Monitor de Atividade: helpers do navegador vão para o navegador, compiladores lançados no terminal vão para o terminal."
        ),
        (
            "Limites", "lock",
            "A CPU de processos do sistema que rodam como administrador (como o kernel) não é legível sem privilégio e fica de fora. A GPU do WindowServer, que desenha a tela, entra na conta."
        ),
        (
            "Ventilador", "fan",
            "Rotação lida do controlador do sistema (SMC) a cada segundo, também sem privilégio de administrador. Abaixo de 100 rpm o ventilador conta como parado. O MacBook Air não tem ventilador, e o TermoBar esconde essa parte."
        ),
        (
            "Limitação térmica", "flame",
            "Vem da pressão térmica publicada pelo kernel. A partir do nível “pesada” o macOS reduz a frequência do chip; esses trechos aparecem destacados no gráfico."
        ),
    ]

    var body: some View {
        Form {
            ForEach(Self.topics, id: \.symbol) { topic in
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            // Largura fixa: os títulos alinham mesmo com símbolos de larguras diferentes.
                            Image(systemName: topic.symbol).frame(width: 22)
                            Text(topic.title)
                        }
                        .font(.headline)
                        Text(topic.text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 520)
    }
}
