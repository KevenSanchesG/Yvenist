---
paths:
  - "docs/**/*.md"
  - "CLAUDE.md"
  - "README.md"
  - "backend/README.md"
  - ".claude/**/*.md"
---

# Documentação e Knowledge Base

Contexto completo: `docs/00-project/memory-system.md`.

- **Cada fato mora em um lugar.** Antes de escrever, busque se já existe; se
  existir, aponte para lá em vez de repetir.
- Texto sem rótulo é fato do código e cita o caminho. Use `[DECISÃO]`,
  `[INFERÊNCIA]`, `[PROPOSTA]`, `TODO` e `OPEN QUESTION` para o resto. **Não
  escreva como fato o que não foi conferido no código.**
- Todo documento de `docs/` começa com cabeçalho: `title`, `type` e `updated`
  (ou `date`), no formato `AAAA-MM-DD`. Ao mudar o conteúdo, atualize a data.
- Links em Markdown com caminho relativo (`[texto](../pasta/arquivo.md)`), não
  `[[wikilinks]]`: têm de funcionar no Obsidian e no GitHub. Evite âncoras de
  título com mais de uma palavra.
- Documento novo: parta de um modelo de `docs/templates/` e inclua uma linha
  no índice da pasta; área nova, uma linha em `memory-system.md`. Não crie
  pasta vazia.
- Motivo de uma escolha vai em um ADR (`docs/05-decisions/`). ADR aceito não é
  reescrito: crie outro e marque o antigo como substituído.
- Números que envelhecem (quantidade de testes) só no changelog, com data.
- Nunca escreva senha, chave, token ou dado pessoal real.
- `CLAUDE.md` fica abaixo de 200 linhas e só tem o que vale para toda sessão.
- O `README.md` da raiz é em inglês, para quem visita o repositório; a
  Knowledge Base é em português.
- Antes de concluir: `python tools/check_docs.py`.
