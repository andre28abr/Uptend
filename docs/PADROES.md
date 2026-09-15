# Padrões do Projeto — Uptend

> Regras de engenharia que valem para todo o projeto, desde o início. Objetivo: código 100% desde o começo, seguro e pronto para distribuição no Homebrew. Este arquivo é referência obrigatória antes de considerar qualquer coisa "pronta".

**Última atualização:** 2026-07-08

---

## 1. Qualidade de código (boas práticas)

- Swift idiomático: nomes claros, funções pequenas, responsabilidade única.
- Sem `!` (force-unwrap) ou `try!` em caminhos que podem falhar; tratar o erro.
- Tratar todos os erros de forma explícita; nunca engolir em silêncio.
- Sem código morto e sem `print` de depuração no código final.
- Comentários explicam o **porquê**, não o óbvio.
- SwiftUI: views pequenas e compostas; estado no lugar certo (`@State` / `@StateObject` / `@EnvironmentObject`).
- `swift build` deve terminar **sem warnings** antes de considerar pronto.

## 2. Testes automatizados

- Criar testes sempre que a lógica tiver risco de quebrar: parsing, validação, transformação de dados, regras de negócio, mapeamentos.
- Framework: **Swift Testing** (`import Testing`, `@Test`, `#expect`). Alvo `UptendTests`.
- Rodar com: `./test.sh` (usa o toolchain do Xcode, necessário para o framework de testes).
- Focar em **lógica pura**. UI não precisa de teste unitário — validar visualmente.
- Regra: todo avanço mantém `./test.sh` **verde**. Se um bug for encontrado, escrever primeiro um teste que o reproduz.

## 3. Segurança (Security by Design)

O app roda comandos de sistema e será distribuído publicamente. Segurança é requisito, não opcional.

### Execução de comandos
- **Nunca** usar shell (`/bin/sh -c`, `system()`, interpolação de string em comando). Sempre `Process` com `arguments: [String]` — sem shell, sem interpolação. (Já é o padrão em `Shell.swift`.)
- Validar toda entrada que vira argumento, via allowlist/regex (`InputValidator`). Ex.: tokens do Homebrew só `^[A-Za-z0-9@._+-]+$`. Defesa em profundidade, mesmo sem shell.
- **Menor privilégio**: rodar como usuário comum. `sudo` só quando estritamente necessário, explícito e com consentimento do usuário.
- Nunca desabilitar SIP, Gatekeeper ou proteções do sistema.

### Frameworks de referência (revisar a cada feature)
- **OWASP Top 10** — injection, insecure design, security misconfiguration, componentes vulneráveis, etc.
- **OWASP ASVS** — checklist de verificação.
- **NIST SSDF (SP 800-218)** — processo de desenvolvimento seguro.
- **CWE Top 25** — classes de bug mais comuns.

### Dados e dependências
- Parsing seguro (`Codable`, tratar falha sem crash). Sem desserialização insegura.
- **Minimizar dependências externas** (superfície de ataque / supply chain). Fixar versões e revisar cada uma.
- Nenhum segredo/credencial no código.

### Revisão
- A cada feature relevante, passar um **pente fino de segurança** (rodar o skill `/security-review`, revisar contra OWASP/CWE, checar entradas validadas).
- Registrar achados e correções no `HISTORICO.md`.

## 4. Privacidade (Privacy by Design)

- **Local-first**: tudo roda na máquina do usuário. Sem telemetria, sem analytics, sem envio de dados pessoais.
- Sem conexões de rede além das estritamente necessárias (ex.: o próprio Homebrew baixa pacotes). Qualquer rede nova deve ser transparente e justificada ao usuário.
- Logs não contêm dados sensíveis e nunca saem da máquina.
- Coletar o mínimo, guardar o mínimo.

## 5. Distribuição (preparar desde já)

- **Assinar** o app (Developer ID) e **notarizar** na Apple antes de distribuir.
- Publicar como **cask do Homebrew** com checksum (sha256) verificável.
- Versionamento **SemVer** + changelog.

## 6. Definição de Pronto (Definition of Done)

Uma feature só está "pronta" quando:

- [ ] Compila sem warnings.
- [ ] Testes relevantes criados e `./test.sh` verde.
- [ ] Revisão de segurança feita (entradas validadas, OWASP/CWE, sem shell).
- [ ] Sem regressão de privacidade (nada vaza, nenhuma rede indevida).
- [ ] Registrada no `HISTORICO.md`.
