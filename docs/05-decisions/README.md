---
title: Decisões (ADRs)
type: index
updated: 2026-10-03
---

# Decisões (ADRs)

Um ADR registra **uma escolha entre alternativas** e o motivo. Não descreve
como o código está (isso é [arquitetura](../01-architecture/overview.md)); diz
por que está assim, para ninguém desfazer sem saber o que perde.

| ADR | Decisão | Situação |
|---|---|---|
| [001](ADR-001-camadas-por-funcionalidade.md) | App em pastas por funcionalidade, com contratos de repositório e uma raiz de composição | aceita |
| [002](ADR-002-estado-com-provider.md) | Estado com Provider e `ChangeNotifier` | aceita |
| [003](ADR-003-api-monolito-modular.md) | API própria: FastAPI síncrono, monólito modular | aceita |
| [004](ADR-004-autenticacao.md) | JWT curto + token de renovação rotativo; Argon2id | aceita |
| [005](ADR-005-festa-gravada-por-estado.md) | A festa é gravada inteira, por estado desejado, com versão | aceita |
| [006](ADR-006-concorrencia-pelo-banco.md) | Corridas são decididas pelo banco | aceita |
| [007](ADR-007-dinheiro-e-snapshots.md) | Dinheiro em centavos; item guarda cópia de nome e preço | aceita |
| [008](ADR-008-acessibilidade-e-cores.md) | Dois laranjas; contraste testado pelos tokens | substituída por ADR-017 |
| [009](ADR-009-erros-uniformes.md) | Um formato de erro, em português, com código estável | aceita |
| [010](ADR-010-fila-de-analise.md) | Recusar um cadastro recusa os anúncios dele; a tela só publica o que mostrou | aceita (confirmada pelos donos) |
| [011](ADR-011-knowledge-base-em-docs.md) | Knowledge Base em `docs/`, aberta pelo Obsidian, sem MCP | aceita |
| [012](ADR-012-ci-a-cada-envio.md) | CI a cada envio, em cinco jobs | aceita |
| [013](ADR-013-identificador-do-app.md) | Identificador `com.yvenist.app` | substituída por ADR-016 |
| [014](ADR-014-textos-legais-como-assets.md) | Textos legais como arquivos do app, com versão casada à da API | aceita |
| [015](ADR-015-paginas-legais-publicas.md) | Páginas legais públicas geradas dos mesmos arquivos do app | aceita |
| [016](ADR-016-identificador-br-com-yvenist-app.md) | Identificador `br.com.yvenist.app`, seguindo o domínio dos donos | aceita (decisão dos donos) |
| [017](ADR-017-um-laranja-e-tema-escuro.md) | Um laranja por tema (`#C2410C`), tema escuro e a escolha em Aparência | aceita (decisão dos donos) |
| [018](ADR-018-tela-inteira-em-qualquer-android.md) | O app desenha a tela inteira (borda a borda) em qualquer Android | aceita |
| [019](ADR-019-festa-como-composicao-de-evento.md) | A festa é a composição de um evento: itens configurados por categoria, estimativa separada do orçamento, orçamento por item respondido pelo fornecedor | aceita, aguardando confirmação dos donos |

## Quando criar um ADR

Crie quando houve **alternativa real** e a escolha vai durar:

- trocar ou adotar uma biblioteca, um serviço, um formato;
- uma regra de negócio que podia ser de outro jeito;
- uma estrutura (de pastas, de tabela, de API) que o resto do código vai seguir;
- algo que parece estranho e tem motivo.

Não crie para correção de defeito, ajuste de texto, ou escolha que qualquer
pessoa faria igual.

## Como criar

1. Copie [`templates/adr.md`](../templates/adr.md) para
   `ADR-NNN-nome-curto.md`, com o próximo número.
2. Preencha todas as seções. "Alternativas consideradas" não pode ficar vazia:
   sem alternativa não é uma decisão.
3. Acrescente a linha na tabela acima.
4. Um ADR aceito não é reescrito. Se a decisão mudar, crie outro e marque o
   antigo como "substituída por ADR-NNN".

## Situações

`proposta` (ainda em discussão) · `aceita` · `substituída por ADR-NNN` ·
`rejeitada`.
