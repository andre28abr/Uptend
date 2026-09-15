# Política de segurança

## Reportando vulnerabilidades

Não abra issue pública para uma vulnerabilidade. Abra um [GitHub Security Advisory privado](https://github.com/andre28abr/Uptend/security/advisories/new) ou escreva para o mantenedor pelo e-mail do [perfil](https://github.com/andre28abr).

A resposta sai em até 7 dias. É um projeto de portfólio sem SLA comercial: a gravidade pauta a prioridade.

## Escopo

**São vulnerabilidades reportáveis:** injeção de comando por qualquer campo que chegue ao `Process` (hostname, caminhos, nomes de pacote, campos do JSON do coletor), execução de código a partir dos relatórios HTML, Markdown ou do playbook gerado, vazamento do token do GitHub ou de senhas SSH para fora do Keychain (linha de comando, logs, `.git/config`), caminhos temporários previsíveis, falha do `rollback` do playbook que deixe o servidor pior do que estava, quebra da assinatura do JSON do coletor, dependências ou toolchain vulneráveis.

**Não são vulnerabilidades:** o app não ser notarizado pela Apple (assinatura ad-hoc, documentada), o coletor precisar de `sudo` no servidor auditado para ler o que audita, o `accept-new` de fingerprint SSH (TOFU) documentado.

## Defesas existentes

- Zero dependências externas; `Process` sempre com argumentos em array, nunca shell.
- Token do GitHub via `GIT_ASKPASS` e Keychain; senhas SSH no Keychain.
- JSON do coletor tratado como entrada adversarial; escape em HTML, Markdown e script gerado.
- Playbook aplica correções com backup e `rollback` num só comando.
- Auditoria de segurança de ponta a ponta com teste de regressão para cada achado; 428 testes e zero warnings no CI.

## Histórico de divulgações

Nenhuma vulnerabilidade reportada até o momento.
