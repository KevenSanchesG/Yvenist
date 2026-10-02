---
title: "ADR-014: Textos legais como arquivos do app, com a versão casada à da API"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-014: Textos legais como arquivos do app, com a versão casada à da API

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica;
os donos pediram o rascunho dos textos (commit `7e0f230`)

## Contexto

O cadastro exige marcar "Li e aceito os Termos de Uso e a Política de
Privacidade", e a API grava qual versão foi aceita (`users.terms_version`). Mas
os textos não existiam: o link levava a uma tela dizendo "em elaboração".

## Problema

Onde os textos moram, como são mostrados e como a versão aceita se mantém
verdadeira?

## Decisão

- Os textos são **arquivos Markdown dentro do app** (`assets/legal/`),
  versionados com o código.
- Foram escritos **a partir do que o código faz**, e cada ponto que depende dos
  donos ou de um advogado fica entre colchetes no próprio texto.
- A tela mostra um **aviso de versão preliminar** na lista e em cada documento.
- Um leitor próprio, pequeno, entende só o subconjunto de Markdown que os
  textos usam. Nenhum pacote novo.
- **A versão é uma só**: a linha "Versão" de cada documento tem de ser igual ao
  `terms_version` da API. Um teste do app lê os dois e compara.
- Enquanto houver um colchete, o texto tem de se dizer "(preliminar)": outro
  teste garante.

## Consequências

- A pessoa consegue ler o que está aceitando, mesmo sem rede.
- O registro de aceite aponta para um texto que existe no repositório, naquela
  versão.
- Mudar o texto exige publicar uma versão nova do app.
- Não há reaceite: quem aceitou a versão anterior não é avisado quando o texto
  muda. OPEN QUESTION para quando os textos forem finais.
- A loja exige a política em uma URL pública; o arquivo do app não resolve isso
  sozinho.
- **Não substitui revisão jurídica.**

## Alternativas consideradas

- **Textos servidos pela API ou por uma página web**: permitiria corrigir sem
  nova versão do app e daria a URL pública; exige hospedagem que ainda não
  existe. É o caminho natural quando houver.
- **Pacote `flutter_markdown`**: está descontinuado no pub.dev (substituído
  pelo `flutter_markdown_plus`, da comunidade; conferido em 2026-10-02). Para
  quatro marcações não compensa uma dependência.
- **Texto fixo no código Dart**: mistura conteúdo jurídico com código e
  dificulta a revisão por quem não programa.
- **Continuar com "em elaboração"**: o app seguiria registrando o aceite de um
  texto inexistente.
