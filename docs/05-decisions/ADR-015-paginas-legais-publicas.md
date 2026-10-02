---
title: "ADR-015: Páginas legais públicas geradas dos mesmos arquivos do app"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-015: Páginas legais públicas geradas dos mesmos arquivos do app

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica.
Onde hospedar as páginas é decisão dos donos.

## Contexto

Os textos legais são arquivos do app
([ADR-014](ADR-014-textos-legais-como-assets.md)) e só aparecem dentro dele. A
Play Store exige dois endereços públicos (conferido na ajuda do Play Console
em 2 de outubro de 2026):

- a política de privacidade;
- uma página onde a pessoa possa **pedir a exclusão da conta sem ter o app**,
  que cite o nome do app e deixe o caminho do pedido em evidência.

Não existe hospedagem, e a escolha dela está em aberto
([roadmap](../00-project/roadmap.md)).

## Problema

Como ter esses endereços sem escrever os textos duas vezes e sem depender de
onde a API vai ser hospedada?

## Decisão

- `tools/build_legal_site.py` gera páginas HTML estáticas a partir dos mesmos
  arquivos Markdown: a política e os termos de `assets/legal/`, mais
  `deploy/site/exclusao-de-conta.md`, que só existe no site.
- O gerador lê o mesmo subconjunto de Markdown que o app, e um teste usa o
  mesmo exemplo do teste do app para os dois não divergirem.
- Cada página se basta: sem script, sem fonte de fora, sem chamada a terceiros.
- Enquanto um texto tiver um trecho entre colchetes, a página dele mostra o
  aviso de versão preliminar, com as mesmas palavras do app.
- A saída vai para `build/legal-site/` e não é versionada.

## Consequências

- Serve em qualquer hospedagem de arquivos estáticos, com um comando.
- O texto continua tendo um lugar só.
- Mudar um texto passa a pedir duas publicações: uma versão nova do app e as
  páginas geradas de novo.
- A página de exclusão de conta não aparece dentro do app: lá a exclusão é
  feita direto em Perfil → Segurança.
- **Nada foi publicado.** Enquanto as páginas não estiverem em um endereço, a
  exigência da loja continua em aberto ([KI-02](../07-known-issues/README.md)).

## Alternativas consideradas

- **A API servir os textos** (`/legal/…`): daria o endereço em qualquer
  hospedagem da API, e era o caminho sugerido no ADR-014. Os textos ficam fora
  da pasta que vira a imagem da API (`backend/`); seria preciso mudar a
  montagem da imagem ou copiar os textos. Vale rever quando a hospedagem
  existir.
- **O proxy da receita de `deploy/` servir os arquivos**: só atende quem
  escolher o servidor próprio.
- **Usar a versão web do app**: pesada para um texto, ilegível sem JavaScript
  e baixa arquivos de terceiros ([personal-data](../01-architecture/personal-data.md)).
- **Escrever as páginas à mão**: dois textos para manter iguais.
