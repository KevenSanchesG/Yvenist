---
title: Roadmap
type: project
updated: 2026-10-02
---

# Roadmap

O que falta, separado por quem pode resolver. Nada aqui tem data: nenhuma foi
combinada.

## Decisões que são dos donos (Rafael e Keven)

| OPEN QUESTION | Por que trava |
|---|---|
| Mesclar `feat/professional-foundation` na `main`? | todo o trabalho desde o protótipo está na branch |
| Qual o tom do laranja da marca? | `#FF6600` tem contraste 2,94:1 sobre branco; hoje fica só em ícones ([ADR-008](../05-decisions/ADR-008-acessibilidade-e-cores.md)) |
| Quem revisa os textos legais e quais são os dados da empresa? | termos e política têm trechos entre colchetes ([legal](../03-features/legal.md)) |
| Em que endereço ficam a política e a página de exclusão de conta? | a Play Store exige as duas em endereços públicos; as páginas já são geradas ([legal](../03-features/legal.md)) |
| Idade mínima: basta a declaração ao aceitar os termos, ou o app pergunta a data de nascimento? | os textos dizem 18 anos e o app não confere |
| Para que servem o telefone e a data de nascimento? | são pedidos e nenhuma função os usa ([personal-data](../01-architecture/personal-data.md)) |
| Como o Yvenist cobra? | o app promete anúncio gratuito; não há cobrança no código |
| Onde a API vai ser hospedada? | sem API em `https` não há build de release utilizável. Os dois caminhos (servidor próprio com a receita de `deploy/`, ou uma plataforma de contêineres) estão em [deployment](../09-guides/deployment.md) |
| O "orçamento" deve chegar aos fornecedores? | hoje é só uma estimativa para o cliente |
| Em que ordem entram as funções "Em breve"? | veja a lista abaixo |

## Para publicar no Android

Passo a passo, e o que a loja exige, em
[android-release](../09-guides/android-release.md). Falta: criar a chave de
envio, hospedar a API em `https` ([deployment](../09-guides/deployment.md)),
fechar os textos legais, publicar a política de privacidade e a página de
exclusão de conta, e a conta de desenvolvedor.

## Para o iOS

Nunca foi compilado: exige um Mac. O que já está pronto no projeto e a lista
do que fazer no Mac: [ios-build](../09-guides/ios-build.md).

## Funções previstas ("Em breve")

O que já existe para cada uma:

| Função | Já existe | Falta |
|---|---|---|
| Página de detalhe do anúncio | `GET /catalog/listings/{id}` | a tela |
| Dispositivos conectados | `GET /users/me/sessions`, `DELETE /users/me/sessions/{id}` | a tela |
| Cadastro de outras categorias | API aceita qualquer categoria | formulário por categoria |
| Meus Anúncios | `GET /vendors/me/listings` | a tela; edição de anúncio não existe na API |
| Fotos do anúncio | campo `cover_image_url` (uma URL) | envio e armazenamento de arquivos |
| Data e convidados da festa | domínio e API aceitam (`event_at`, `guest_count`) | os campos na tela |
| Renomear e cancelar festa | domínio e API aceitam | os botões na tela |
| Pagamentos | status `paid` no ciclo da festa | tudo: provedor, fluxo, telas |
| Chat, notificações, avaliações | nada (só as colunas `rating_*` do anúncio) | tudo |
| Recuperar senha, confirmar e-mail | nada | serviço de e-mail e fluxo |
| Autenticação em dois fatores | nada | tudo |

## Dívidas técnicas

Estão em [problemas conhecidos](../07-known-issues/README.md), com o gatilho
que torna cada uma urgente.

## `[PROPOSTA]` Ordem sugerida

1. Mesclar a branch e hospedar a API (sem isso nada chega a usuários).
2. Fechar os textos legais e publicar no Android em teste interno.
3. Página de detalhe do anúncio e data/convidados da festa: a API já atende, e
   são o que mais falta para a festa montada ser útil.
4. Decidir o que o orçamento vira (pedido ao fornecedor?) antes de pagamentos.
