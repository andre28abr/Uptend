# Uptend

Um canivete suíço para **configurar e manter o seu Mac** — pensado para reinstalar tudo com um clique depois de formatar. Nativo em SwiftUI, leve, com foco em segurança e privacidade (tudo roda localmente, sem telemetria).

*up* (uptime / upkeep) + *tend* (cuidar) = manter o Mac em dia.

## O que faz

- **Setup** — modo "primeira vez" (passo a passo), perfis de **Brewfile** (exporte sua seleção e reinstale tudo numa próxima formatação) e restauração de **dotfiles**.
- **Homebrew** — buscar, instalar, ver instalados, atualizar e manutenção (`update`, `cleanup`, `doctor`), com log ao vivo.
- **Aplicativos** — lista os apps de `/Applications` e desinstala (movendo para a Lixeira + arquivos residuais).
- **Limpeza** — Lixeira, caches, logs, downloads antigos e caches de dev (Xcode, npm, CocoaPods), com aviso de reversibilidade.
- **Git** — monitora pastas de repositórios, mostra status e faz pull/push/fetch.
- **Docker** — lista containers, imagens, volumes e redes (OrbStack/Docker Desktop) e gerencia.
- **Rede** — velocidade ao vivo (gráficos), Wi-Fi, qualidade/latência, endereços (IP/gateway/DNS/MAC), conexões ativas e teste de velocidade.
- **Segurança** — status de FileVault, Firewall, Gatekeeper, SIP e atualizações; gerador de senhas e hash SHA-256.
- **Sistema** — informações do Mac, itens de inicialização e vários ajustes rápidos (Finder, Dock, teclado, capturas).
- **Ferramentas** — conversores, QR Code, chave SSH, portas em uso e histórico de clipboard.
- **Barra de menu** — mini painel de CPU, memória e rede com mini-gráficos.

## Requisitos

- macOS 14 ou superior
- Xcode (para compilar) — [Homebrew](https://brew.sh) é recomendado para as funções de instalação

## Como rodar

```bash
# Compila e abre o app
./build-app.sh

# Ou abra Package.swift no Xcode e rode com Cmd+R
```

## Testes

```bash
./test.sh
```

## Gerar o DMG

```bash
./make-dmg.sh   # gera build/Uptend.dmg
```

> O DMG é assinado apenas ad-hoc. Para distribuir sem o aviso do Gatekeeper, é preciso
> assinar com **Developer ID** e **notarizar** na Apple (veja abaixo).

## Distribuição (notarização)

Para publicar de verdade:

1. Assinar com Developer ID: `codesign --deep --options runtime --sign "Developer ID Application: SEU NOME (TEAMID)" build/Uptend.app`
2. Notarizar: `xcrun notarytool submit build/Uptend.dmg --keychain-profile "AC_PASSWORD" --wait`
3. Grampear: `xcrun stapler staple build/Uptend.dmg`

## Privacidade e segurança

- **Local-first**: nada é enviado para servidores. As únicas conexões de rede são ações explícitas (IP público, teste de velocidade) e claramente sinalizadas.
- Comandos do sistema rodam via `Process` com argumentos em array (nunca via shell), com validação de entrada como defesa em profundidade.
- Ações destrutivas são reversíveis (Lixeira) e pedem confirmação.

## Licença

MIT — veja [LICENSE](LICENSE).
