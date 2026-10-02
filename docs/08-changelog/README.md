---
title: Changelog
type: index
updated: 2026-10-02
---

# Changelog

O que mudou no projeto, por data. É o único lugar com números que envelhecem
(quantidade de testes, versões): cada entrada é uma fotografia do dia.

| Período | Documento |
|---|---|
| Outubro de 2026 | [2026-10](2026-10.md) |
| Relatório da fundação profissional (2 de outubro de 2026) | [2026-10-fundacao-profissional](2026-10-fundacao-profissional.md) |
| Relatório da memória persistente (2 de outubro de 2026) | [2026-10-memoria-persistente](2026-10-memoria-persistente.md) |

O histórico linha a linha está no Git (`git log`). Aqui fica o resumo que uma
pessoa lê: o que mudou **para quem usa ou mantém** o projeto, e o que foi
verificado.

## Como registrar

Uma entrada por dia de trabalho relevante, no arquivo do mês (`AAAA-MM.md`), a
mais recente em cima:

```markdown
## AAAA-MM-DD — título curto

**Mudou**
- o que passou a existir ou a se comportar diferente (com o commit)

**Verificado**
- o que foi conferido, onde e com que resultado

**Ficou em aberto**
- o que não foi feito ou não foi verificado
```

- Escreva o resultado, não o esforço.
- "Verificado" só entra com evidência: um comando que rodou, um job do CI.
- Problema resolvido: tire-o de [problemas conhecidos](../07-known-issues/README.md)
  e cite aqui.
- Decisão tomada: o motivo vai para um [ADR](../05-decisions/README.md); aqui só
  a referência.
