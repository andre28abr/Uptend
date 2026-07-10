# Uptend — protótipo de interface

Prévia da interface gráfica (SwiftUI), com **dados de exemplo (mock)**. Serve só para avaliar o UX. Ainda não faz nada real — nenhum comando de shell é executado.

## Como rodar

### Opção 1 — script (duplo-clique no .app)
```bash
./build-app.sh          # compila em release e abre o Uptend.app
./build-app.sh --debug  # compila mais rápido (debug)
```
Gera `build/Uptend.app`. Não é DMG — é só o app local.

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
Sources/Uptend/
  App/        UptendApp (entrada), AppState (estado global)
  Model/      Category (categorias + subseções), Models, MockData
  Views/      RootView (layout 3 colunas), Components, e uma view por categoria
```

O layout é um `NavigationSplitView` de 3 colunas: categorias | subseções | conteúdo.

## Regras de design aplicadas
- Ícones = SF Symbols (flat, nativos), sempre com tooltip via `.help()`.
- Sem emojis.
- Tema claro/escuro (Configurações > Geral, ou acompanha o sistema).
- Listas, poucas animações, cara de Mac nativo.

## Próximos passos
- Ajustar o UX conforme feedback.
- Ligar cada categoria à lógica real (Homebrew, Docker, Git, limpeza…).
- Só no fim: empacotar em DMG.
