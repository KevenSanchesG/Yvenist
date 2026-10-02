---
title: "ADR-010: Recusar um cadastro recusa os anúncios dele; a tela só publica o que mostrou"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-010: Recusar um cadastro recusa os anúncios dele; a tela só publica o que mostrou

**Status:** aceita, **aguardando confirmação dos donos** (é regra de negócio) ·
**Data:** 2026-10-02 · **Decidida por:** evolução técnica, ao construir a tela
de administração (commit `bcece5c`)

## Contexto

O fornecedor envia o cadastro junto com o primeiro anúncio. Um administrador
analisa os dois. Um anúncio só pode ser publicado se o cadastro estiver
aprovado. Um cadastro recusado pode ser corrigido e reenviado, e o reenvio
cria um anúncio novo.

## Problema

Ao construir a tela da fila apareceram dois defeitos da regra antiga:

1. Recusar o cadastro deixava o anúncio "em análise". Quando o fornecedor
   corrigia e reenviava, havia dois anúncios pendentes; a aprovação publicava
   os dois e **o mesmo salão aparecia duas vezes no catálogo**. Reproduzido por
   teste antes da correção.
2. A fila de anúncios não dizia de quem era cada anúncio, então a tela não
   tinha como explicar por que "publicar" era recusado.

## Decisão

- **Recusar um cadastro recusa junto os anúncios que aguardavam com ele**, com
  o mesmo motivo. Só os pendentes; anúncios de outros fornecedores não mudam.
- A fila de anúncios responde também com o fornecedor (id, nome, situação) e a
  data de envio.
- **Na tela**, "Publicar" fica desabilitado enquanto o cadastro não foi
  aprovado, com a explicação.
- **A aprovação de um cadastro só publica junto o que apareceu na tela**: se a
  fila (limitada a 50) não trouxe anúncios daquele fornecedor, o app manda
  `publish_pending_listings: false`.
- Depois de qualquer decisão a fila é recarregada, tenha dado certo ou não.

## Consequências

- Nenhum anúncio é publicado sem ter estado diante de quem decide.
- A fila não acumula anúncios que nunca poderiam ser publicados.
- O fornecedor recusado vê o anúncio como recusado, com o motivo do cadastro, e
  ao reenviar manda um anúncio novo. O antigo fica no histórico dele.
- O padrão da **API** continua sendo publicar junto
  (`publish_pending_listings: true`); quem chamar a API por fora da tela precisa
  saber disso.

## Alternativas consideradas

- **Deixar como estava e documentar**: o administrador teria de recusar o
  anúncio antigo à mão antes de aprovar o reenvio. Fácil de esquecer; o
  resultado é um anúncio duplicado em público.
- **O reenvio atualizar o anúncio pendente em vez de criar outro**: muda o
  contrato do cadastro (o app teria de saber qual anúncio está corrigindo).
- **Apagar os anúncios pendentes na recusa**: o fornecedor perderia o que
  enviou e não veria o motivo.
- **Aprovar sempre sem publicar** e exigir uma decisão por anúncio: mais
  seguro e mais lento; no caso comum (um cadastro, um anúncio) dobra o trabalho.
