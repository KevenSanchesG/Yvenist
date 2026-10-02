---
title: "ADR-004: JWT curto, token de renovação rotativo, Argon2id"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-004: JWT curto, token de renovação rotativo, Argon2id

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica
(commits `a12aea5`, `c9afed1`, `5708104`)

## Contexto

O app é de celular: a pessoa entra uma vez e espera continuar dentro por
semanas. A sessão fica guardada no aparelho e as chamadas saem por redes que
caem.

## Problema

Como manter a pessoa autenticada por muito tempo sem que um token copiado
valha para sempre?

## Decisão

- **Token de acesso**: JWT de 15 minutos, com o algoritmo fixado na validação.
- **Token de renovação**: opaco e aleatório, válido por 30 dias; o banco guarda
  só o SHA-256. A cada uso ele é trocado por outro (**rotação**).
- **Reuso**: um token já trocado que reaparece encerra todas as sessões
  nascidas do mesmo login (a "família").
- **Troca de senha** incrementa `token_version` e invalida na hora os tokens de
  acesso antigos.
- **Senha**: Argon2id; mínimo de 8 caracteres; recusa das mais comuns; sem
  regra de composição (NIST SP 800-63B).
- **No app**: tokens no cofre do sistema; uma única renovação em andamento
  mesmo com várias chamadas falhando juntas; sem rede a sessão não é apagada.
- **Força bruta**: limite por IP no login e no cadastro.

## Consequências

- Um token de acesso vazado vale no máximo 15 minutos.
- A API confere a conta a cada requisição (existe, está ativa, versão confere):
  uma consulta a mais por chamada.
- Renovação estrita: se a resposta de uma renovação se perde no caminho, a
  próxima tentativa usa um token já trocado e a sessão cai. A pessoa entra de
  novo.
- Na web o "cofre" é o armazenamento do navegador
  ([problema conhecido](../07-known-issues/README.md)).

## Alternativas consideradas

- **Sessão por cookie**: boa para a web, ruim para o app nativo.
- **JWT de longa duração, sem renovação**: não dá para revogar.
- **Token de renovação sem rotação**: uma cópia valeria os 30 dias inteiros.
- **Regras de composição de senha** (maiúscula, número, símbolo): pioram as
  senhas reais; a lista de senhas comuns ataca o problema certo.
- **bcrypt**: aceitável; Argon2id é a recomendação atual e resiste melhor a
  hardware dedicado.
- **Provedor de identidade externo**: mais um serviço e um custo, sem
  necessidade hoje. Login social segue possível depois.
