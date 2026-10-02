---
name: atualizar-memoria
description: Registra na Knowledge Base do Yvenist (docs/) o que mudou depois de uma tarefa relevante — escolhe o documento certo, cria um ADR quando houve decisão, atualiza problemas conhecidos e changelog, e confere os links. Use ao terminar uma funcionalidade, uma correção de defeito ou uma mudança de regra, de estrutura, de decisão ou de processo; e quando pedirem para "atualizar a memória", "documentar" ou "registrar a decisão".
---

# Atualizar a memória do projeto

A Knowledge Base é a pasta `docs/`. O índice é
`docs/00-project/memory-system.md`. O objetivo é que uma sessão nova, amanhã,
consiga continuar o trabalho só com o que está lá.

## 1. Vale registrar?

Registre quando mudou o que o projeto **faz**, como ele é **montado**, uma
**regra**, uma **decisão**, um **limite conhecido** ou o **jeito de trabalhar**.

Não registre: correção de digitação, renomeação, formatação, refatoração que
não muda comportamento nem estrutura. Nesses casos, pare aqui.

## 2. Levante o que mudou

```bash
git status --short
git diff --stat
git log --oneline -15
```

Liste, em frases, o que passou a ser diferente. É isso que será registrado: o
resultado, não o esforço.

## 3. Ache o lugar de cada fato

Um fato mora em **um** documento. Busque antes de escrever (`Grep` em `docs/`
pelo termo): se já existe, corrija lá.

| O que mudou | Onde registrar |
|---|---|
| comportamento de uma funcionalidade | o documento dela em `docs/03-features/` |
| **qualquer coisa do Party Maker** | o arquivo indicado em `docs/03-features/party-maker/README.md` |
| regra de negócio | `docs/02-domain/` (ou `party-maker/business-rules.md`) |
| estrutura do app | `docs/01-architecture/clean-architecture.md` |
| rota, contrato ou limite da API | `docs/01-architecture/backend.md` |
| tabela, coluna, índice | `docs/01-architecture/data-model.md` |
| segurança | `docs/01-architecture/security.md` |
| o que é coletado, guardado ou enviado a terceiros | `docs/01-architecture/personal-data.md` e `assets/legal/politica-de-privacidade.md` |
| produção, hospedagem, HTTPS | `docs/09-guides/deployment.md` |
| testes: onde ficam, o que provam | `docs/01-architecture/testing.md` |
| cor, componente, tela | `docs/04-ux/` |
| termo novo | `docs/00-project/glossary.md` |
| escolha entre alternativas | **ADR novo** (passo 4) |
| pesquisa em fonte externa | `docs/06-research/` |
| problema, limite ou pendência descobertos | `docs/07-known-issues/README.md` |
| problema resolvido | tire de `07-known-issues` e cite no changelog |
| comando, ambiente, CI, publicação | `docs/09-guides/` |
| o que os donos precisam decidir | `docs/00-project/roadmap.md`, como `OPEN QUESTION` |

Documento novo: copie o modelo de `docs/templates/` e inclua uma linha no
índice da pasta (`README.md`). Área nova: uma linha no mapa de
`memory-system.md`.

## 4. Houve decisão? Crie um ADR

Só se houve alternativa real e a escolha vai durar.

1. Copie `docs/templates/adr.md` para
   `docs/05-decisions/ADR-<número>-<nome-curto>.md`, com o próximo número.
2. Preencha: contexto, problema, decisão, consequências (inclusive o que se
   perde), alternativas consideradas, data, e quem decidiu.
3. Inclua a linha na tabela de `docs/05-decisions/README.md`.
4. Decisão de negócio tomada sem os donos: situação "aceita, aguardando
   confirmação dos donos", e uma linha em `docs/07-known-issues/README.md`.

Um ADR aceito não é reescrito. Se a decisão mudou, crie outro e marque o
antigo como "substituída por ADR-NNN".

## 5. Escreva

- Só o que está no código, com o caminho do arquivo. O que não é fato leva
  rótulo: `[INFERÊNCIA]`, `[PROPOSTA]`, `TODO`, `OPEN QUESTION`.
- Frases curtas, em português. Tabela para o que é lista de itens parecidos.
- Atualize `updated:` no cabeçalho de cada documento alterado.
- Links em Markdown com caminho relativo.
- Nunca senha, chave, token ou dado pessoal real.

## 6. Changelog

Uma entrada no arquivo do mês em `docs/08-changelog/` (formato em
`docs/08-changelog/README.md`), a mais recente em cima: o que **mudou**, o que
foi **verificado** (com a evidência) e o que **ficou em aberto**. É o único
lugar onde entram números que envelhecem.

Se o estado geral mudou (algo passou a funcionar, uma pendência fechou),
atualize também "Estado atual" em `docs/00-project/memory-system.md`.

## 7. Confira

```bash
python tools/check_docs.py
```

Corrija tudo o que ele apontar: link quebrado, documento fora do índice,
cabeçalho faltando, caminho citado que não existe.

## 8. Pergunta de fechamento

*Se eu abrir uma sessão nova amanhã, a Knowledge Base tem tudo o que preciso
para continuar isto?* Se a resposta for "falta X", registre X.

Por fim, diga ao usuário, em uma lista curta, quais documentos foram
alterados e por quê. A documentação entra no mesmo commit da mudança que ela
descreve.
