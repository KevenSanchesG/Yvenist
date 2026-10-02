---
title: Knowledge Base do Yvenist
type: index
updated: 2026-10-02
---

# Knowledge Base do Yvenist

Esta pasta é a memória do projeto e um cofre do Obsidian. Comece pelo índice:

**[Sistema de memória](00-project/memory-system.md)**

| Pasta | Conteúdo |
|---|---|
| `00-project` | visão, glossário, roadmap e o índice |
| `01-architecture` | como o app e a API são montados |
| `02-domain` | regras de negócio por assunto |
| `03-features` | cada funcionalidade; o Party Maker tem uma pasta própria |
| `04-ux` | design system, acessibilidade, telas |
| `05-decisions` | ADRs: por que cada escolha foi feita |
| `06-research` | o que foi pesquisado antes de decidir |
| `07-known-issues` | o que está quebrado, limitado ou pendente |
| `08-changelog` | o que mudou, por data |
| `09-guides` | como rodar, testar, publicar |
| `templates` | modelos para documentos novos |
| `screenshots` | capturas geradas das telas reais por um teste |

## Abrir no Obsidian

Abra **esta pasta** (`docs`) como cofre. A configuração vem junto no
repositório: links em Markdown com caminho relativo, modelos em `templates/`,
nenhum plugin da comunidade. Detalhes: [obsidian](09-guides/obsidian.md).

## Conferir

```bash
python tools/check_docs.py
```
