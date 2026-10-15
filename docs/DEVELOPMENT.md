# Desenvolvimento

Como compilar, testar e distribuir o TermoBar, e como o código está organizado. Para usar o app, veja o [README](../README.pt-BR.md).

## Compilar

Requisitos: Mac com Apple Silicon, macOS 15 ou superior, Xcode 16 ou superior e [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project TermoBar.xcodeproj -scheme TermoBar -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/TermoBar.app /Applications/
open /Applications/TermoBar.app
```

O projeto Xcode é gerado a partir do `project.yml` e não fica no repositório.

O ícone (`TermoBar/AppIcon.icon`) é um documento do Icon Composer e só é compilado a partir do Xcode 26. Com versões anteriores, o app compila e funciona, mas fica com o ícone genérico do macOS.

## Testes e formatação

```sh
xcodebuild test -project TermoBar.xcodeproj -scheme TermoBar -destination 'platform=macOS,arch=arm64'
swift format lint --strict --recursive TermoBar TermoBarTests TermoBarWidget
```

Os testes (Swift Testing) cobrem a lógica pura — agregação, ranking, alertas, histórico SQLite, CSV e preferências — e não dependem de sensores. O CI (`.github/workflows/ci.yml`) roda a formatação e os testes em cada pull request.

## Distribuir (assinado e notarizado)

```sh
./scripts/release.sh
```

Gera em `build/release/`:

- `TermoBar-<versão>.dmg`: abre numa janela de instalação com fundo, o app à esquerda, uma seta e o atalho para Aplicativos à direita.
- `TermoBar-<versão>.zip`: o mesmo app compactado.

O app é só arm64, assinado com o Developer ID do time `F22LFNZSAZ`, notarizado pela Apple e com o resultado carimbado (abre mesmo sem internet); o DMG também é assinado, notarizado e carimbado. O script para se a assinatura, a notarização ou o Gatekeeper recusarem o app.

O DMG é montado por `scripts/make-dmg.sh` com o [dmgbuild](https://github.com/dmgbuild/dmgbuild), que grava a disposição da janela direto no `.DS_Store`, sem depender do Finder. Na primeira vez o script cria um ambiente Python em `build/dmgbuild` e instala o dmgbuild nele; por isso precisa do `python3`. O fundo é desenhado por `scripts/dmg/background.swift` em 1x e 2x, e as posições dos ícones ficam em `scripts/dmg/settings.py`.

Pré-requisitos, uma vez por Mac: o certificado **Developer ID Application** do time no Keychain e as credenciais do `notarytool` no perfil `TermoBar`:

```sh
xcrun notarytool store-credentials TermoBar --apple-id <apple-id> --team-id F22LFNZSAZ
```

Rode esse comando no Terminal, não por outra ferramenta: ele pede a senha de app (gerada em account.apple.com) de forma interativa. Os builds de desenvolvimento e o CI continuam com assinatura local e não precisam do certificado.

### Atualizações (Sparkle)

O app se atualiza pelo [Sparkle](https://sparkle-project.org). Ele lê o `appcast.xml` em `https://github.com/gbrlrg/termo-bar/releases/latest/download/appcast.xml`, ou seja, o anexo da versão mais recente no GitHub, e só instala o zip se a assinatura EdDSA conferir com a chave pública do `Info.plist` (`SUPublicEDKey` no `project.yml`).

O `release.sh` reassina os auxiliares do Sparkle com o Developer ID (o pacote vem com assinatura ad hoc, que a notarização recusa) e, no fim, gera o `build/release/appcast.xml` assinado. Para publicar uma versão, crie a tag `v<versão>` no GitHub e anexe **os três arquivos**: o DMG, o zip e o `appcast.xml`. Sem o `appcast.xml` anexado, quem já tem o app não fica sabendo da versão nova.

A chave privada fica no Keychain deste Mac, na conta `br.com.gbrlrg.termobar`, e não vai para o repositório. Sem ela não dá para publicar atualizações que os apps instalados aceitem. Guarde uma cópia num lugar seguro e restaure em outro Mac com as ferramentas do pacote (ficam em `build/release/SourcePackages/artifacts/sparkle/Sparkle/bin/` depois de um build):

```sh
generate_keys --account br.com.gbrlrg.termobar -x termobar-sparkle.key   # exporta
generate_keys --account br.com.gbrlrg.termobar -f termobar-sparkle.key   # importa
```

### Widget

O widget (`TermoBarWidget/`) roda em sandbox e lê só o resumo que o app grava no App Group `F22LFNZSAZ.br.com.gbrlrg.termobar`. O App Group exige a assinatura do time: nos builds de desenvolvimento (assinatura ad hoc) o app não consegue gravar, registra um erro uma vez e segue sem o widget. Para testar o widget localmente, compile assinando com o Developer ID:

```sh
xcodebuild -project TermoBar.xcodeproj -scheme TermoBar -derivedDataPath build/signed \
    CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM=F22LFNZSAZ \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build
```

## Idiomas

O app está em português e inglês. Quem usa o Mac em outro idioma vê o inglês, que é o idioma padrão do projeto (`developmentLanguage: en` e `CFBundleDevelopmentRegion: en`).

Os textos são escritos em português direto no código e funcionam como chaves do `TermoBar/Localizable.xcstrings`, que guarda o inglês e o português de cada um:

- Literais do SwiftUI (`Text("…")`, `Button("…")`, `Toggle("…")`) são traduzidos sozinhos.
- Texto montado como `String` (rótulos de enums, notificações, detalhes de gráfico) usa `String(localized: "…")`.
- Componentes que recebem um título fixo usam `LocalizedStringKey` (`CardTitle`, `Stat`, `TemperatureStepper`, `SettingsFootnote`).
- Logs e o cabeçalho do CSV não são traduzidos.

Depois de criar ou mudar um texto, compile e sincronize o catálogo:

```sh
xcodebuild -project TermoBar.xcodeproj -scheme TermoBar -derivedDataPath build/l10n build
xcrun xcstringstool sync TermoBar/Localizable.xcstrings \
    --stringsdata $(find build/l10n -name '*.stringsdata' | grep -v Tests)
```

A chave nova entra no catálogo sem tradução: preencha o inglês e repita o texto em português (`pt-BR`). Sem o `pt-BR`, quem usa o Mac em português vê o inglês, porque o macOS cai no idioma padrão. Para conferir, abra o app com `-AppleLanguages "(en)"` ou `"(pt-BR)"`, junto das variáveis de captura abaixo.

## Arquitetura

O código é dividido em camadas; as de cima dependem das de baixo, nunca o contrário.

| Pasta | Responsabilidade |
|---|---|
| `App/` | Ponto de entrada, raiz de composição (`AppDependencies`) e captura de tela de diagnóstico |
| `Intents/` | Ações do app Atalhos e frases da Siri (App Intents) |
| `Shared/` | Resumo gravado pelo app e lido pelo widget (`WidgetSnapshot`), compilado nos dois alvos |
| `UI/` | Telas SwiftUI: barra de menus, popover, Ajustes, componentes e tema. Recebem os serviços pelo `Environment` |
| `Services/` | Estado do app e integração com o macOS: coleta (`Monitor`), preferências, notificações, item de login, widget, atualizações (Sparkle) e log |
| `Hardware/` | Leitura do hardware: sensores de temperatura (IOHID), ventoinhas (SMC), energia de CPU por processo, GPU (IOReport/IORegistry) e pressão térmica; `Bridging.h` declara as funções privadas e a estrutura do SMC |
| `Persistence/` | Histórico em SQLite (instruções preparadas, transações) e exportação CSV |
| `Domain/` | Modelo e regras puras, sem AppKit nem SwiftUI: amostras, resumo por minuto e por período, cores por app, política de alertas, unidades e formatação |

| Arquivo | Responsabilidade |
|---|---|
| `Domain/Sample.swift` | Registro do histórico, resumo por minuto e cálculos sobre coleções de amostras |
| `Domain/RangeSummary.swift` | Agregação por período: ranking, barras empilhadas, linhas do tempo |
| `Domain/AlertPolicy.swift` | Quando avisar: temperatura sustentada, limitação térmica, app acima do limite, intervalo entre repetições |
| `Hardware/TemperatureSensors.swift` | Sensores do die e filtro de leituras implausíveis |
| `Hardware/FanReader.swift` | Rotação, mínimo e máximo de cada ventoinha, lidos do AppleSMC |
| `Hardware/EnergySampler.swift` | Energia de CPU por processo e agrupamento por app responsável |
| `Hardware/GPUSampler.swift` | Energia da GPU, tempo de GPU por processo e correção do WindowServer |
| `Services/Monitor.swift` | Coleta a cada segundo, fecha registros, resume por minuto e mantém o estado da interface |
| `Persistence/HistoryStore.swift` | Leitura e escrita do histórico |

## Segurança e privacidade

- Todo valor gravado no SQLite entra por parâmetro (`?`), nunca interpolado no SQL; as escritas de cada registro são atômicas.
- O CSV exportado neutraliza nomes de processo que começam com `=`, `+`, `-` ou `@`, para não virarem fórmulas numa planilha.
- A pasta do histórico é criada com permissão só para o usuário, e "Apagar histórico" compacta o arquivo para não deixar os dados no disco.
- Preferências fora da faixa válida (editadas com `defaults write`) são corrigidas ao abrir o app.
- O app roda com o runtime endurecido do macOS. Ele não pode usar o App Sandbox, porque lê a energia de processos de outros apps e usa APIs privadas do IOKit. O widget, que só lê o resumo do App Group, roda em sandbox.
- A única conexão de rede é a busca por atualizações (Sparkle), que lê o `appcast.xml` no GitHub; cada atualização só é instalada se a assinatura EdDSA conferir.
- Falhas de banco e de notificação vão para o log unificado (`log stream --predicate 'subsystem == "br.com.gbrlrg.termobar"'`).

## Diagnóstico (build Debug)

| Variável | Efeito |
|---|---|
| `TERMOBAR_SNAPSHOT=<arquivo.png>` | Abre o popover numa janela e salva uma captura |
| `TERMOBAR_SNAPSHOT_DELAY=<s>` | Espera antes da captura (padrão 3 s) |
| `TERMOBAR_SETTINGS_TAB=<aba>` | Captura uma aba dos Ajustes (`geral`, `barra`, `alertas`, `sensores`, `dados`, `precisao`, `sobre`) |
| `TERMOBAR_PIN=<bundle id>` | Abre com o app fixado na lista, mostrando os processos dele |
| `TERMOBAR_APPEARANCE=light\|dark` | Força o tema |
| `TERMOBAR_LOG=1` | Imprime cada registro: temperatura, GPU total, pressão térmica e os apps que mais consomem |
| `TERMOBAR_EXPORT=<arquivo.csv>` | Exporta as leituras das últimas 24 h antes de sair |

```sh
TERMOBAR_LOG=1 build/Build/Products/Debug/TermoBar.app/Contents/MacOS/TermoBar
```
