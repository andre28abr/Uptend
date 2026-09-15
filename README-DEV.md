# Uptend — guia de desenvolvimento

Notas para compilar, testar e navegar o código. A visão geral do produto está no [README.md](README.md).

## Como rodar

### Opção 1 — script (duplo-clique no .app)
```bash
./build-app.sh            # compila em release e abre o Uptend.app
./build-app.sh --debug    # compila mais rápido (debug)
./build-app.sh --install  # compila e atualiza /Applications/Uptend.app
```
Gera `build/Uptend.app` (saída de compilação). O app "instalado" mora em
`/Applications` — use `--install` para atualizá-lo. Não é DMG — é só o app local.

### Opção 2 — Xcode
Abra `Package.swift` no Xcode e rode com Cmd+R.

### Opção 3 — linha de comando
```bash
swift run
```

## Testes
```bash
./test.sh   # roda a suíte com o toolchain do Xcode (Swift Testing)
```

## Padrões
Antes de considerar qualquer coisa pronta, seguir o `../PADROES.md` (qualidade, testes, Security by Design, Privacy by Design, Definition of Done).

## Estrutura

```
Sources/UptendCore/   Lógica pura, sem SwiftUI/AppKit (relatórios, parsers, auditoria) — testável isolada
Sources/Uptend/
  App/        UptendApp (entrada), AppState (estado global)
  Model/      Category (categorias + subseções), Models, MockData
  Services/   Integrações reais (Homebrew, Git/GitHub, Docker, ssh, scanners…)
  Views/      RootView (layout 3 colunas), Components, e uma view por categoria
Tests/UptendTests/    Suíte de testes (Swift Testing)
```

O layout é um `NavigationSplitView` de 3 colunas: categorias | subseções | conteúdo.

## Regras de design aplicadas
- Ícones = SF Symbols (flat, nativos), sempre com tooltip via `.help()`.
- Sem emojis.
- Tema claro/escuro (Configurações > Geral, ou acompanha o sistema).
- Listas, poucas animações, cara de Mac nativo.

## Empacotamento
```bash
./make-dmg.sh   # gera build/Uptend.dmg (assinatura ad-hoc; ver README.md para notarização)
```
