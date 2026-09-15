# CLAUDE.md

> **Antes de decidir qualquer coisa, leia `~/Documents/Dev/raiz/`** (PERFIL.md e o arquivo do assunto): é como o
> André trabalha. A decisão dele na conversa prevalece sobre qualquer documento; depois, atualize o documento.

Orientações para o Claude Code trabalhar neste repositório. Leia antes de agir.
Referência: [README.md](README.md) (produto), [README-DEV.md](README-DEV.md) (compilar/testar/navegar),
[docs/PADROES.md](docs/PADROES.md) (regras de engenharia — **valem para tudo**), [docs/DECISOES.md](docs/DECISOES.md),
[docs/HISTORICO.md](docs/HISTORICO.md) (diário; **sempre adicionar ao final** quando algo relevante acontece).

## O que é

**Uptend** — app nativo de macOS (Swift 6 + SwiftUI, SwiftPM, zero dependências) com duas metades:
1. **Manutenção do Mac**: setup pós-formatação (Brewfile, dotfiles), Homebrew, apps, limpeza, Git/GitHub, Docker, rede,
   segurança, sistema, ferramentas, barra de menu.
2. **Auditoria de servidores Linux**: coletor portátil em shell (`Sources/Uptend/Resources/audit-collector.sh`) → JSON
   assinado → painel, relatórios (MD/HTML/PDF/dataset), superfície de ataque, CVEs, MITRE, detecção, deriva, frota,
   exceções de risco, lente LGPD e playbook de hardening com rollback. Também HomeLab (hosts remotos via SSH).

Interface em português; código e identificadores em inglês; comentários em português. Sem emojis na UI; ícones SF Symbols.

## Como rodar / testar

```bash
./build-app.sh --debug        # compila e abre build/Uptend.app (--install atualiza /Applications)
swift run                     # pelo SwiftPM
./test.sh                     # 428 testes / 70 suítes (Swift Testing) com o toolchain do Xcode, ~13 s
swift build                   # tem que ficar em 0 warnings
swiftlint                     # opcional (brew install swiftlint); regras em .swiftlint.yml
```

O CI (GitHub Actions, macOS) roda build + testes a cada push. Requer Xcode 16+ (Swift 6 e Swift Testing).
Pastas `.build/` e `build/` são cache/saída, ignoradas pelo git — pode apagar.

## Estrutura

- `Sources/UptendCore/` — **lógica pura, sem SwiftUI/AppKit**: relatórios, parsers, correlações, playbook. Tudo que
  puder viver aqui, vive aqui: é testável sem UI e sem Mac de verdade.
- `Sources/Uptend/App/` — `UptendApp`, `AppState`. `Model/` — `Category` (categorias e subseções do menu), `Models`.
- `Sources/Uptend/Services/` — integrações reais. `Shell`/`CommandRunner` (processos), `BrewService`, `GitService`,
  `GitHubService` + `GitAuth`, `DockerService`, `SSHService` + `Remote*`, `ExternalAuditService`, `Keychain`, `UptendVault`.
- `Sources/Uptend/Views/` — uma view por categoria, `RootView` (NavigationSplitView de 3 colunas), `Components`.
- `Tests/UptendTests/` — Swift Testing; `Fixtures/lab-audit.json` é uma auditoria real do lab.
- `docs/` — planejamento vivo. `lab/` — VMs OrbStack para validar o coletor.

## Regras que não podem quebrar

- **Nunca `sh -c` com string interpolada.** Processos rodam via `Process` com argumentos em array. Entrada do usuário e do
  coletor é validada (defesa em profundidade).
- **O JSON do coletor é adversarial.** Hostname, versões, evidências: escapar antes de virar HTML (`<` em `<script>`),
  Markdown (`mdCell`, cercas dimensionadas por `mdFence`) ou script (`shComment` e o sanitizador de `echo` no playbook). Há testes de
  regressão para cada vetor — mantenha-os e adicione o seu.
- **Segredos só no Keychain.** Token do GitHub via `GIT_ASKPASS` + variável de ambiente do filho; nunca em argv, nunca em
  `.git/config`, nunca em log.
- **Caminhos temporários imprevisíveis** (`mktemp -d`), nunca fixos em `/tmp`, em qualquer coisa que rode em servidor.
- **Ações destrutivas são reversíveis** (Lixeira) e pedem confirmação. O playbook faz backup e tem `rollback`.
- **Sem force-unwrap (`!`) nem `try!`** em caminho que pode falhar. Sem dependências externas sem decisão registrada.
- **Feature nova → teste novo**, no núcleo sempre que possível. `swift build` com 0 warnings antes de commitar.

## Convenções

- Commits em português, imperativo, primeira linha curta com o tema (`Auditoria: …`, `Rede: …`, `Docs: …`).
- `main` é a única branch; releases por tag. Registrar o marco em `docs/HISTORICO.md`.
- Versão/bundle id: `com.andresouza.uptend`. Distribuição: `make-dmg.sh` (ad-hoc); notarização descrita no README-DEV.

## Runtimes e dependências: sempre na última versão

Regra do autor (2026-09): este projeto está em desenvolvimento e deve acompanhar as versões mais novas
de runtime (Python, Node, Go, Rust, Swift) e de bibliotecas. Ao começar a mexer aqui:

1. O Homebrew já foi conferido no início da sessão (hook `brew-check`). Se listou pacotes desatualizados,
   rode `brew upgrade && brew cleanup` antes de qualquer outra coisa.
2. Verifique se há versão nova do runtime e das dependências (`uv lock --upgrade`, `pnpm update`,
   `npm outdated`, `cargo update`, `go get -u ./...`, conforme o projeto) e atualize os pins:
   requirements/pyproject, package.json, Cargo.toml, go.mod, Dockerfile e a matriz do CI.
3. Rode a suíte completa e o lint; faça push e confira o CI. **Só commite atualização com tudo verde.**
4. Se uma dependência não acompanha a versão nova (ex.: sem wheel para o Python mais recente),
   fique na anterior e registre o motivo nesta seção, com data.
