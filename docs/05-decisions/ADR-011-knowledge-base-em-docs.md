---
title: "ADR-011: Knowledge Base em docs/, aberta pelo Obsidian, sem MCP"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-011: Knowledge Base em `docs/`, aberta pelo Obsidian, sem MCP

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** pedido dos donos
(memória persistente com Obsidian integrada ao Claude Code); o desenho é desta
decisão

## Contexto

O projeto é desenvolvido com o Claude Code. Cada sessão começa sem lembrar da
anterior. O Obsidian 1.13 está instalado na máquina de desenvolvimento, com um
cofre vazio. O que foi pesquisado está em
[claude-code-memory](../06-research/claude-code-memory.md) e
[obsidian-integration](../06-research/obsidian-integration.md).

## Problema

Onde guardar o conhecimento do projeto para que uma sessão nova recupere o
contexto sozinha, gastando pouco, e para que pessoas possam ler e editar o
mesmo material?

## Decisão

1. **A Knowledge Base é a pasta `docs/` do repositório**, em Markdown puro, e
   essa mesma pasta é o cofre do Obsidian. Versionada junto com o código.
2. **Quatro camadas**, cada uma carregada só quando precisa:
   `CLAUDE.md` (sempre, curto) → `.claude/rules/` com `paths` (quando um
   arquivo da área é lido) → skill `/atualizar-memoria` (quando invocada) →
   `docs/` (um documento por vez).
3. **Um índice central**, [`memory-system.md`](../00-project/memory-system.md),
   de onde todo documento é alcançável.
4. **Links em Markdown com caminho relativo**, e não `[[wikilinks]]`.
5. **Sem servidor MCP**: o Claude Code lê o cofre com as ferramentas de arquivo
   que já tem (`Glob`, `Grep`, `Read`).
6. **Sem plugins da comunidade** no Obsidian; só os internos.
7. **Um conferidor** (`tools/check_docs.py`), rodado também no CI.

## Consequências

- Código e documentação mudam no mesmo commit e são revisados juntos.
- Os links funcionam em três lugares: no Obsidian, no GitHub e para o Claude
  (que resolve o caminho direto).
- Recuperar contexto custa o `CLAUDE.md`, o índice e os documentos da tarefa,
  e não o cofre inteiro.
- Não há busca semântica nem consulta ao grafo (links de volta, órfãos) a
  partir do Claude. A busca é por texto; o conferidor acha links quebrados e
  documentos órfãos.
- Renomear um arquivo pelo Obsidian atualiza os links (com a opção ligada);
  renomear por fora exige rodar o conferidor.
- Abrir o Claude Code em uma pasta acima do repositório não carrega o
  `CLAUDE.md` na largada.

## Alternativas consideradas

- **Cofre fora do repositório** (o `Documentos\Obsidian Vault` que já existia):
  o conhecimento ficaria só em uma máquina, fora do Git e longe do código que
  descreve.
- **`[[Wikilinks]]`**: mais cômodos de digitar no Obsidian, mas não funcionam
  no GitHub e exigem resolver o nome para um caminho. O Obsidian aceita os dois
  formatos; as referências a blocos, que só existem com wikilinks, não fazem
  falta.
- **Servidor MCP para o Obsidian**: não existe um oficial. Os da comunidade
  pedem um plugin e uma chave de API, ou repetem o que as ferramentas de
  arquivo já fazem; cada um soma definições de ferramenta ao contexto e uma
  superfície a mais para conteúdo externo. O cofre são arquivos dentro do
  repositório: não há o que intermediar.
- **CLI oficial do Obsidian** (desde a 1.12): dá busca e consultas ao grafo,
  mas exige o aplicativo aberto e uma ativação manual. Fica como opção, sem
  ser requisito.
- **Tudo no `CLAUDE.md`**: a documentação recomenda menos de 200 linhas; um
  arquivo grande é carregado inteiro em toda sessão e é seguido pior.
- **Só a memória automática do Claude Code** (`~/.claude/projects/…`): fica em
  uma máquina, não é versionada e não é lida por pessoas.
