---
title: "ADR-012: CI a cada envio, em cinco jobs"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-012: CI a cada envio, em cinco jobs

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica;
o envio da branch e o acompanhamento foram autorizados pelos donos (commits
`fee3c74`, `134a9f5`, `e105c8b`)

## Contexto

A máquina de desenvolvimento é Windows, sem Docker, com o Controle Inteligente
de Aplicativos bloqueando alguns binários. Várias garantias do projeto só
valem em PostgreSQL, em Linux ou dentro de um navegador.

## Problema

Como conferir a cada mudança o que a máquina local não consegue rodar?

## Decisão

Um fluxo do GitHub Actions (`.github/workflows/ci.yml`) que roda em **todo
envio, em qualquer branch**, e por disparo manual. Cinco jobs independentes:

| Job | Garante |
|---|---|
| `app` | formatação, análise estática e testes do Flutter |
| `backend` | lint, tipos, e a suíte em SQLite **e** em PostgreSQL 17 (com os testes de concorrência e as migrações) |
| `integration` | o app real contra a API real com PostgreSQL, na máquina **e dentro do Chrome** |
| `android` | o APK de debug compila |
| `docker` | a imagem e o `docker compose` sobem, a API responde, o processo não é root |

Sem permissão de escrita no repositório. Um envio novo cancela a execução
anterior da mesma branch.

## Consequências

- Docker, PostgreSQL e o navegador são conferidos sem existir na máquina local.
- O job de integração no Chrome achou um defeito que nenhum teste local
  acharia (`1 << 32` vale 0 em JavaScript).
- Cada envio gasta minutos de CI. O repositório é público, então não há custo.
- Rodar em toda branch significa que uma branch de rascunho também é
  verificada: é o objetivo.
- iOS não é coberto (pediria um executor macOS).

## Alternativas consideradas

- **Só em `main` e em pull requests** (a primeira versão): a branch de trabalho
  nunca era verificada até existir um pull request.
- **Testes de integração só na máquina**: não exercitam o CORS nem o cliente
  HTTP do navegador.
- **Rodar os testes web localmente no Windows**: o executor de testes web do
  Flutter falha nessa plataforma
  ([flutter-web-testing](../06-research/flutter-web-testing.md)).
- **Um job único**: uma falha esconderia o resultado dos outros e tudo ficaria
  mais lento.
