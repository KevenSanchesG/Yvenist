---
title: Roadmap
type: project
updated: 2026-10-03
---

# Roadmap

O que falta, separado por quem pode resolver. Nada aqui tem data: nenhuma foi
combinada.

## Decisões que são dos donos (Rafael e Keven)

| OPEN QUESTION | Por que trava |
|---|---|
| Quem revisa os textos legais e quais são os dados da empresa? | termos e política têm trechos entre colchetes ([legal](../03-features/legal.md)) |
| Em que endereço ficam a política e a página de exclusão de conta? | a Play Store exige as duas em endereços públicos; as páginas já são geradas ([legal](../03-features/legal.md)) |
| Idade mínima: basta a declaração ao aceitar os termos, ou o app pergunta a data de nascimento? | os textos dizem 18 anos e o app não confere |
| Para que servem o telefone e a data de nascimento? | são pedidos e nenhuma função os usa ([personal-data](../01-architecture/personal-data.md)) |
| Como o Yvenist cobra? | o app promete anúncio gratuito; não há cobrança no código |
| Onde a API vai ser hospedada? | sem API em `https` não há build de release utilizável. Os dois caminhos (servidor próprio com a receita de `deploy/`, ou uma plataforma de contêineres) estão em [deployment](../09-guides/deployment.md) |
| As decisões de negócio do Party Maker valem como foram feitas? | o orçamento passou a chegar aos fornecedores, item por item, com escolhas que ninguém confirmou: [ADR-019](../05-decisions/ADR-019-festa-como-composicao-de-evento.md) e as perguntas em [party-maker/roadmap](../03-features/party-maker/roadmap.md) |
| O que acontece depois que a pessoa aceita um orçamento? | hoje nada: não reserva, não gera contrato, não cobra |
| Em que ordem entram as funções "Em breve"? | veja a lista abaixo |

## Para publicar no Android

Passo a passo, e o que a loja exige, em
[android-release](../09-guides/android-release.md). A chave de envio já
existe; falta guardar uma cópia dela e das senhas. Falta também: hospedar a
API em `https` ([deployment](../09-guides/deployment.md)), fechar os textos
legais, publicar a política de privacidade e a página de exclusão de conta, e
a conta de desenvolvedor.

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
| Indicar parceiros no anúncio | a API aceita `partner_listing_ids`; a festa já os sugere | a tela no cadastro do fornecedor |
| Pagamentos | status `paid` no ciclo da festa | tudo: provedor, fluxo, telas |
| Chat, notificações, avaliações | nada (só as colunas `rating_*` do anúncio) | tudo. Sem notificação, a resposta de um orçamento só aparece quando a pessoa atualiza a festa |
| Recuperar senha, confirmar e-mail | nada | serviço de e-mail e fluxo |
| Autenticação em dois fatores | nada | tudo |

## Dívidas técnicas

Estão em [problemas conhecidos](../07-known-issues/README.md), com o gatilho
que torna cada uma urgente.

## `[PROPOSTA]` Ordem sugerida

1. Hospedar a API (sem isso nada chega a usuários).
2. Fechar os textos legais e publicar no Android em teste interno.
3. Confirmar com os donos as decisões de negócio do Party Maker (ADR-019)
   antes de mostrá-lo a usuários reais.
4. Página de detalhe do anúncio: a API já atende, e é o que mais falta para a
   pessoa escolher bem o que põe na festa.
5. Avisar a pessoa quando um fornecedor responde, e decidir o que o aceite de
   um orçamento vira (reserva? contrato?), antes de pagamentos.
