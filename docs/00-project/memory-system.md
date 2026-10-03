---
title: Sistema de memória do Yvenist
type: index
updated: 2026-10-03
---

# Sistema de memória do Yvenist

Este é o **índice da memória do projeto**. Quem chega sem contexto (uma pessoa
nova ou uma sessão nova do Claude Code) começa aqui e segue os links só do que
a tarefa pede. A pasta `docs/` é a Knowledge Base e também um cofre do
Obsidian: os mesmos arquivos Markdown servem aos dois.

## O projeto em um parágrafo

O Yvenist é um marketplace de festas e eventos, de Rafael e Keven. Quem vai
comemorar encontra salões e serviços, compõe o evento em um só lugar (o **Party
Maker**), vê uma estimativa e pede o orçamento aos fornecedores; quem oferece
um espaço se cadastra como fornecedor, tem o anúncio publicado depois de uma
análise e responde aos pedidos. São duas peças no mesmo repositório: o app
Flutter (`lib/`) e a API FastAPI com PostgreSQL (`backend/`). Sem API
configurada o app roda sozinho, em modo demonstração. Detalhes:
[visão](vision.md).

## Estado atual (3 de outubro de 2026)

- A `main` tem o trabalho até 2 de outubro de 2026 (commit `8505b1e`). A
  branch `feat/professional-foundation` está **à frente dela**, com o Party
  Maker novo, e foi enviada ao GitHub em 3 de outubro de 2026, a pedido dos
  donos. A mesclagem na `main` não foi pedida. Envio e mesclagem só quando os
  donos pedirem.
- O CI passou nos cinco jobs no envio do Party Maker novo (commit `bfb33f7`).
  O que foi conferido além dele, na máquina (o PostgreSQL com a prova das
  travas e um emulador Android), está no
  [changelog](../08-changelog/2026-10.md). Detalhes do CI: [CI](../09-guides/ci.md).
- Funciona: catálogo e busca (com vários jeitos de cobrar), contas, favoritos,
  Party Maker (compor o evento, estimativa, pedir orçamento, responder como
  fornecedor, edição solicitada, aceite, histórico), cadastro de salão, fila
  de análise para administradores, textos legais preliminares, tema claro e
  escuro à escolha da pessoa.
- **Esperando os donos**: as decisões de negócio do Party Maker
  ([ADR-019](../05-decisions/ADR-019-festa-como-composicao-de-evento.md)).
- Não existe (aparece como "Em breve"): pagamentos, chat, avaliações,
  notificações, envio de fotos, página de detalhe do anúncio.
- Nunca foi publicado em loja nem colocado em produção. A chave de envio do
  Android já existe, fora do repositório
  ([android-release](../09-guides/android-release.md)).

O que mudou e quando: [changelog](../08-changelog/README.md). O que falta:
[roadmap](roadmap.md) e [problemas conhecidos](../07-known-issues/README.md).

## Mapa da Knowledge Base

| Preciso saber... | Leia |
|---|---|
| o que é o produto, para quem, o que existe | [vision](vision.md) |
| o que um termo significa e como se chama no código | [glossary](glossary.md) |
| o que falta e o que depende dos donos | [roadmap](roadmap.md) |
| como o sistema é montado | [01-architecture/overview](../01-architecture/overview.md) |
| as regras que o código segue em todo lugar | [principles](../01-architecture/principles.md) |
| como o app é organizado | [clean-architecture](../01-architecture/clean-architecture.md) |
| como a API é organizada | [backend](../01-architecture/backend.md) |
| tabelas e relações | [data-model](../01-architecture/data-model.md) |
| segurança | [security](../01-architecture/security.md) |
| que dados pessoais são coletados, e para quem vão | [personal-data](../01-architecture/personal-data.md) |
| onde ficam e o que provam os testes | [testing](../01-architecture/testing.md) |
| regras de negócio por assunto | [02-domain](../02-domain/README.md) |
| uma funcionalidade específica | [03-features](../03-features/README.md) |
| **o Party Maker** | [03-features/party-maker](../03-features/party-maker/README.md) |
| cores, tipografia, acessibilidade, telas | [04-ux](../04-ux/design-system.md) |
| por que algo foi feito de um jeito | [05-decisions](../05-decisions/README.md) (ADRs) |
| o que foi pesquisado antes de decidir | [06-research](../06-research/README.md) |
| o que está quebrado, limitado ou pendente | [07-known-issues](../07-known-issues/README.md) |
| o que mudou, por data | [08-changelog](../08-changelog/README.md) |
| como rodar e testar | [development](../09-guides/development.md), [ci](../09-guides/ci.md), [web](../09-guides/web.md) |
| como pôr a API no ar, com HTTPS | [deployment](../09-guides/deployment.md) |
| como publicar no Android | [android-release](../09-guides/android-release.md) |
| o que falta para o iOS, e o que fazer no Mac | [ios-build](../09-guides/ios-build.md) |
| como usar este cofre no Obsidian | [obsidian](../09-guides/obsidian.md) |

## Como a memória funciona

Quatro camadas, da mais barata para a mais detalhada:

| Camada | Onde | Quando é lida |
|---|---|---|
| Memória global | `CLAUDE.md` na raiz do repositório | sempre, ao abrir a sessão |
| Regras por área | `.claude/rules/*.md` | só quando o Claude lê um arquivo da área |
| Procedimento | `.claude/skills/atualizar-memoria/` | só quando é invocado |
| Knowledge Base | `docs/` (este cofre) | sob demanda, um documento por vez |

O porquê desse desenho está no [ADR-011](../05-decisions/ADR-011-knowledge-base-em-docs.md).

### Como ler este cofre

Texto sem rótulo é **fato do código**: está implementado e vem com o caminho
do arquivo de onde foi tirado. O resto é sempre rotulado:

| Rótulo | Significa |
|---|---|
| `[DECISÃO]` | escolha registrada em um ADR (o link acompanha) |
| `[INFERÊNCIA]` | deduzido do código ou do histórico, sem confirmação dos donos |
| `[PROPOSTA]` | sugestão ainda não implementada nem aprovada |
| `TODO` | trabalho conhecido que falta fazer |
| `OPEN QUESTION` | pergunta que só os donos do produto respondem |

Se o código e um documento discordarem, **o código vence**: corrija o
documento.

### Início de sessão

1. Confirmar a raiz do repositório (onde estão `pubspec.yaml` e `CLAUDE.md`).
2. Ler `CLAUDE.md` (o Claude Code carrega sozinho quando a sessão é aberta na
   raiz).
3. Localizar a Knowledge Base (`docs/`) e ler este arquivo.
4. Conferir a saúde da Knowledge Base: `python tools/check_docs.py`.
5. Conferir o estado do código: `git status`, `git log --oneline -10`, branch
   atual.
6. Ver o que mudou depois da última atualização dos documentos: os commits
   mais novos que a entrada do topo do [changelog](../08-changelog/README.md)
   ainda não estão descritos aqui.
7. Pelo mapa acima, abrir só os documentos da tarefa e os ADRs que eles citam.
8. Regras da área (`.claude/rules/`) carregam sozinhas quando um arquivo da
   área é lido.
9. Comparar documento e código antes de confiar: se divergirem, o código vence
   e o documento é corrigido na mesma tarefa.
10. Só então trabalhar.

### Consulta

Não leia o cofre inteiro. Parta deste índice, ou busque pelo termo (`Grep` em
`docs/`), e abra o documento que responde. Um documento aponta para os
vizinhos; siga o link só se precisar.

### Atualização (depois de cada tarefa relevante)

Uma tarefa é relevante quando muda o que o projeto faz, como ele é montado, uma
regra, uma decisão, um limite conhecido ou o jeito de trabalhar. Correção de
texto, renomeação e ajuste de estilo não entram.

| O que mudou | Onde registrar |
|---|---|
| comportamento de uma funcionalidade | o documento dela em `03-features/` |
| regra de negócio | o documento do domínio ou da funcionalidade |
| **qualquer coisa do Party Maker** | o arquivo certo em `03-features/party-maker/` |
| estrutura do app ou da API, tabela, rota | `01-architecture/` |
| uma escolha entre alternativas | um ADR novo em `05-decisions/` |
| problema descoberto, limite, pendência | `07-known-issues/README.md` |
| problema resolvido | tirar de `07-known-issues` e citar no changelog |
| o que foi feito, com data | `08-changelog/` |
| comando, ambiente, publicação | `09-guides/` |

O passo a passo está na skill `/atualizar-memoria`. A pergunta de fechamento é
sempre a mesma: *se eu abrir uma sessão nova amanhã, a Knowledge Base tem tudo
o que preciso para continuar isto?*

### Sem redundância

Cada fato mora em um lugar. Os outros documentos apontam para ele. Motivos
ficam nos ADRs; "como está" fica na arquitetura e nas funcionalidades; números
que mudam a cada commit (quantidade de testes) ficam só no changelog, com data.

### Como acrescentar uma área

Crie o documento na pasta numerada certa a partir de um modelo de
`docs/templates/`, inclua uma linha no índice da pasta (`README.md`) e, se for
uma área nova de verdade, uma linha no mapa acima. Não crie pasta vazia.

### Conferência automática

`python tools/check_docs.py` confere os links, o cabeçalho dos documentos, se
cada um é alcançável a partir deste índice e se não há segredo escrito. O CI
roda a mesma conferência a cada envio.
