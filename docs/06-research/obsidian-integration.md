---
title: "Pesquisa: integração entre o Obsidian e o Claude Code"
type: research
date: 2026-10-02
---

# Pesquisa: integração entre o Obsidian e o Claude Code

**Pergunta:** como usar o Obsidian como camada de memória do projeto, e por
qual caminho o Claude Code deve alcançar as notas?

**Fontes** (lidas em 2026-10-02):

- Ajuda oficial do Obsidian: <https://obsidian.md/help/data-storage>,
  <https://obsidian.md/help/links>, <https://obsidian.md/help/cli>,
  <https://obsidian.md/help/plugins/templates>
- Busca na web por servidores MCP para o Obsidian (resultados de terceiros;
  veja a ressalva no fim)

## O que as fontes oficiais dizem

- **Cofre é uma pasta** qualquer do disco, com as notas em texto puro. A
  configuração do cofre fica em `.obsidian/`, na raiz dele.
- `workspace.json` e `workspaces.json` guardam a disposição das janelas; a
  própria ajuda sugere deixá-los fora do Git.
- **Não criar um cofre dentro de outro**: os links são locais ao cofre.
- Configuração global (lista de cofres): `%APPDATA%\Obsidian\` no Windows.
- **Links**: dois formatos equivalentes, `[[Wikilink]]` e
  `[texto](caminho.md)`. A opção fica em *Settings → Files and links → Use
  [[Wikilinks]]* (os nomes são os da ajuda em inglês; o aplicativo em
  português os traduz). Em links Markdown, espaços viram `%20`. Referência a
  bloco (`#^id`) só existe no Obsidian.
- *Automatically update internal links* corrige os links quando um arquivo é
  renomeado pelo aplicativo.
- **Modelos**: plugin interno *Templates*; pasta configurável (*Template
  folder location*); variáveis `{{title}}`, `{{date}}`, `{{time}}`.
- **CLI oficial**: desde a versão 1.12 (instalador 1.12.7 ou mais novo). Exige
  o aplicativo aberto. Ativa-se em *Settings → General → Command line
  interface*. Comandos de leitura, busca, `links`, `backlinks`, `unresolved`,
  `orphans`, propriedades, modelos; o cofre é escolhido com `vault=<nome>`.

## O que foi encontrado nesta máquina

| Item | Situação antes |
|---|---|
| Obsidian | instalado, versão 1.13.7 |
| Cofre registrado | `Documentos\Obsidian Vault`, **vazio**: só a configuração padrão |
| CLI | disponível nesta versão, **não ativada** (`obsidian` não está no `PATH`) |
| Plugins da comunidade | nenhum |

## O que foi feito

- A pasta `docs/` do repositório foi registrada como cofre e passou a ser o que
  abre por padrão. O cofre vazio continua registrado, intacto.
- A configuração do cofre (`docs/.obsidian/`) partiu da configuração padrão
  que o Obsidian tinha criado no cofre vazio, com os ajustes descritos em
  [obsidian](../09-guides/obsidian.md).
- Conferência: o aplicativo foi aberto no cofre, na nota do índice (título da
  janela: "memory-system - docs - Obsidian 1.13.7"), e ao gravar a
  configuração manteve as chaves de link e de modelos.

## Servidores MCP

Não há servidor MCP **oficial** do Obsidian. Os caminhos que aparecem:

| Caminho | O que exige |
|---|---|
| Plugin da comunidade "Local REST API" (com MCP embutido nas versões recentes, segundo os resultados da busca) | instalar plugin de terceiros, aplicativo aberto, chave de API |
| Servidores MCP que leem a pasta do cofre | um processo a mais, repetindo o que as ferramentas de arquivo do Claude Code já fazem |
| CLI oficial | aplicativo aberto e ativação manual |
| **O Claude Code direto nos arquivos** | nada |

## Conclusão

O cofre é a pasta `docs/` do repositório, em Markdown puro. O Claude Code já
lê, busca e edita esses arquivos com as próprias ferramentas, escolhendo um
documento por vez. Um servidor MCP não acrescentaria alcance; acrescentaria
uma dependência, definições de ferramenta no contexto e um ponto a mais por
onde conteúdo de terceiros poderia entrar. Decisão registrada no
[ADR-011](../05-decisions/ADR-011-knowledge-base-em-docs.md).

O que se perde sem MCP ou CLI: consultar o grafo (links de volta, órfãos) e a
busca do Obsidian a partir do Claude. Compensação: `tools/check_docs.py` acha
links quebrados e documentos órfãos; a busca é por texto.

## Para reavaliar

- Se o cofre passar a ter conteúdo **fora** do repositório.
- Se fizer falta consultar o grafo: ativar a CLI oficial é o primeiro passo
  (é do próprio Obsidian e não pede plugin).
- Se o Obsidian publicar um servidor MCP oficial.

## Ressalva

A parte sobre servidores MCP vem de páginas de terceiros achadas pela busca,
não da documentação oficial, e não foi testada. Vale como panorama, não como
especificação.
