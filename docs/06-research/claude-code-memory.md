---
title: "Pesquisa: como o Claude Code guarda e carrega memória"
type: research
date: 2026-10-02
---

# Pesquisa: como o Claude Code guarda e carrega memória

**Pergunta:** o que o Claude Code carrega sozinho em uma sessão nova, quando, e
quanto custa?

**Fontes** (documentação oficial, lida em 2026-10-02):

- <https://code.claude.com/docs/en/memory>
- <https://code.claude.com/docs/en/skills>
- <https://code.claude.com/docs/en/mcp>

## O que as fontes dizem

### `CLAUDE.md`

- Locais: `./CLAUDE.md` ou `./.claude/CLAUDE.md` (projeto, vai para o Git);
  `~/.claude/CLAUDE.md` (pessoal); `./CLAUDE.local.md` (pessoal do projeto,
  fora do Git).
- Os da pasta de trabalho **e das pastas acima** carregam ao abrir a sessão. Os
  de **subpastas** carregam só quando o Claude lê um arquivo lá dentro.
- Meta: **menos de 200 linhas** por arquivo. Arquivo maior consome contexto e é
  seguido pior.
- `@caminho` importa outro arquivo, mas **não economiza contexto**: o importado
  também carrega na largada (até quatro níveis).
- Comentários HTML em bloco (`<!-- … -->`) são retirados antes de entrar no
  contexto: servem para notas a quem mantém o arquivo.
- É contexto, não configuração obrigatória. Para algo que tem de acontecer
  sempre, o mecanismo é um *hook*.
- Depois de compactar a conversa, o `CLAUDE.md` da raiz é relido do disco.
- `/context` mostra o que carregou; `/memory` lista e abre os arquivos;
  `/doctor` propõe cortes (tira o que dá para deduzir do código, mantém
  armadilhas, motivos e convenções).

### `.claude/rules/`

- Arquivos `.md`, descobertos recursivamente.
- Sem cabeçalho: carregam na largada, como o `CLAUDE.md`.
- Com `paths:` (lista de padrões *glob*): carregam **só quando o Claude lê um
  arquivo que casa**. É o único campo lido do cabeçalho.
- Padrões: `**/*.ts`, `src/**/*`, `src/**/*.{ts,tsx}`.

### Skills

- `.claude/skills/<nome>/SKILL.md`. Só o nome e a descrição ficam no contexto;
  o corpo carrega **quando a skill é invocada** (por `/nome` ou pelo próprio
  Claude).
- Descrição cortada em 1 536 caracteres. Recomendação: `SKILL.md` com menos de
  500 linhas.
- Indicação das fontes: `CLAUDE.md` para fatos e convenções; skill para um
  procedimento de vários passos; regra com `paths` para o que só vale em parte
  do código.

### Memória automática

- `~/.claude/projects/<projeto>/memory/`, com um `MEMORY.md` de índice (as
  primeiras 200 linhas ou 25 KB carregam em toda sessão).
- **Fica na máquina**: não vai para o Git nem para outra máquina.
- O `<projeto>` vem do repositório Git; fora de um repositório, da pasta em que
  a sessão foi aberta.

### `AGENTS.md`

O Claude Code lê `AGENTS.md` quando não há `CLAUDE.md` na pasta de trabalho nem
acima. Havendo `CLAUDE.md`, lê só ele.

### MCP

- Configuração de projeto em `.mcp.json`, com aprovação a cada servidor.
- As fontes avisam: confiar em cada servidor antes de conectar; servidores que
  buscam conteúdo externo expõem a injeção de instruções.
- As definições de ferramenta de cada servidor ocupam contexto (há carga
  adiada, mas não é de graça).

## O que isso significou para o Yvenist

| Achado | Consequência no projeto |
|---|---|
| `CLAUDE.md` deve ser curto e não ter o que se deduz do código | o `CLAUDE.md` tem identidade, comandos, regras críticas e os protocolos; a arquitetura fica em `docs/` |
| Importar não economiza contexto | o `CLAUDE.md` **cita** os documentos entre crases, em vez de importar com `@` |
| Regras com `paths` carregam sob demanda | as convenções de app, API, testes, Party Maker e documentação são regras com `paths` |
| Corpo de skill só carrega ao invocar | o passo a passo de atualizar a memória é uma skill |
| A memória automática é local | o que importa está em `docs/`; a memória local só aponta para lá |
| `CLAUDE.md` de subpasta carrega só sob demanda | o Claude Code deve ser aberto **na raiz do repositório** (veja abaixo) |

## Um cuidado deste projeto

O repositório fica em `…\Projeto\Yvenist`, e a pasta `…\Projeto` não é um
repositório. Abrir o Claude Code em `Projeto` faz o `CLAUDE.md` do Yvenist ser
tratado como arquivo de subpasta: ele só carrega depois que o Claude lê algo
dentro de `Yvenist\`. Por isso existe um `CLAUDE.md` mínimo em `…\Projeto`
(fora do Git, só na máquina de desenvolvimento), que manda ler o do
repositório antes de qualquer tarefa. Ele não usa `@` para importar: o arquivo
de uma pasta acima também carrega quando a sessão é aberta dentro de
`Yvenist\`, e a importação poria as mesmas instruções duas vezes no contexto.
O caminho recomendado continua sendo abrir a sessão dentro de `Yvenist\`.

## Conferido em uma sessão de verdade

Em 2 de outubro de 2026 uma sessão nova do Claude Code 2.1.287 foi aberta na
raiz do repositório, sem nenhum contexto, e recebeu seis perguntas sobre o
projeto. O que se observou:

- o `CLAUDE.md` do repositório e o da pasta acima já estavam no contexto, com
  a lista de skills (incluindo `/atualizar-memoria`);
- a regra `.claude/rules/documentation.md` carregou sozinha quando o primeiro
  documento de `docs/` foi lido;
- a sessão seguiu o protocolo (índice, `git status`, `git log`), leu 8 dos 72
  documentos, conferiu dois pontos contra o código e respondeu certo às seis
  perguntas.

Os números estão no [changelog](../08-changelog/2026-10.md).
