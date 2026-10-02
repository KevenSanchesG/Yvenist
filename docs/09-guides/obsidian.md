---
title: Usar a Knowledge Base no Obsidian
type: guide
updated: 2026-10-02
---

# Usar a Knowledge Base no Obsidian

A pasta `docs/` é um cofre do Obsidian. Os arquivos são Markdown puro: tudo o
que está aqui também funciona sem o Obsidian (no GitHub, em qualquer editor).
Motivo do desenho: [ADR-011](../05-decisions/ADR-011-knowledge-base-em-docs.md).

## Abrir

No Obsidian: *Open another vault → Open folder as vault* e escolha a pasta
`docs` do repositório (os nomes são os da interface em inglês). **Abra a pasta
`docs`, não a raiz do repositório**: o cofre é só a documentação.

Na máquina de desenvolvimento o cofre já está registrado e é o que abre por
padrão. Conferido em 2 de outubro de 2026, no Obsidian 1.13.7: o cofre abriu
com a nota do índice e manteve a configuração abaixo.

## O que já vem configurado

A configuração do cofre é versionada em `docs/.obsidian/`:

| Arquivo | O que define |
|---|---|
| `app.json` | links novos em Markdown (`useMarkdownLinks`), com caminho relativo (`newLinkFormat`); links atualizados ao renomear um arquivo (`alwaysUpdateLinks`); anexos colados vão para `attachments/`; a pasta `templates/` fica fora da busca e do grafo |
| `core-plugins.json` | plugins internos ligados: explorador, busca, grafo, links de volta, propriedades, modelos, estrutura do documento. Desligados: notas diárias e Obsidian Sync |
| `templates.json` | a pasta dos modelos (`templates`) e o formato de data (`AAAA-MM-DD`) |

Nenhum plugin da comunidade. O que é de cada pessoa (disposição das janelas,
tema, atalhos) fica fora do Git: veja o `.gitignore` da raiz.

## Navegar

- Comece em [memory-system](../00-project/memory-system.md): todo documento é
  alcançável de lá.
- Cada pasta numerada tem um índice (`README.md`).
- O painel de links de volta mostra quem cita o documento aberto; o grafo
  mostra o cofre inteiro.
- Para achar um assunto: a busca do Obsidian. Para filtrar por tipo de
  documento, busque pela propriedade, por exemplo `[type:adr]`.

## Propriedades (o cabeçalho de cada documento)

| Propriedade | Uso |
|---|---|
| `title` | o título |
| `type` | `index`, `project`, `architecture`, `domain`, `feature`, `ux`, `adr`, `research`, `known-issues`, `changelog`, `guide`, `meeting` |
| `updated` ou `date` | quando o conteúdo mudou pela última vez, ou a data da decisão/pesquisa |
| `status` | só nos ADRs |
| `tags` | só para um assunto que atravessa pastas. Hoje existe uma: `party-maker` |

## Criar um documento

1. Crie a nota na pasta certa.
2. Comando *Templates: Insert template* e escolha o modelo (`adr`, `feature`,
   `business-rule`, `entity`, `research`, `known-issue`, `meeting`).
3. Inclua uma linha no índice da pasta.
4. Rode `python tools/check_docs.py` antes de enviar.

## Cuidados

- **Links em Markdown, não `[[wikilinks]]`.** O cofre já cria assim. Um
  wikilink digitado à mão não funciona no GitHub.
- **Renomeie e mova arquivos pelo Obsidian**: ele corrige os links. Por fora,
  rode o conferidor.
- **Não ligue o Obsidian Sync neste cofre**: quem sincroniza é o Git.
- **Não crie outro cofre dentro deste**, nem abra a raiz do repositório como
  cofre.
- Plugin da comunidade novo é uma decisão: registre em um ADR.
- Nada de senha, chave ou dado pessoal real nas notas.

## Opcional: a linha de comando do Obsidian

Desde a versão 1.12 o Obsidian tem uma CLI oficial, que dá acesso à busca e ao
grafo (links de volta, órfãos, links não resolvidos) pelo terminal. Ela exige
o aplicativo aberto e uma ativação manual: *Settings → General → Command line
interface*. Não é necessária para nada do projeto; o que foi pesquisado está em
[obsidian-integration](../06-research/obsidian-integration.md).
