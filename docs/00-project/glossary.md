---
title: Glossário
type: project
updated: 2026-10-03
---

# Glossário

O termo como aparece para o usuário, o que significa e como se chama no
código. Na API os nomes são os mesmos do app, em `snake_case`.

## Produto

| Termo | Significado | No código |
|---|---|---|
| Anúncio | um espaço ou serviço oferecido por um fornecedor | `Listing` (app e API) |
| Categoria | o que é oferecido: salão, atração, buffet... Um anúncio tem uma | `CatalogCategory`; slugs `venue`, `attraction`, `kids`, `buffet`, `decoration`, `beauty`, `dj`, `staff`, `security`, `other` |
| Salão | o anúncio da categoria `venue`. É a única categoria com cadastro pelo app | `venue` |
| Tipo de evento | a ocasião: casamento, 15 anos... Um anúncio atende vários | `EventType`; slugs `wedding`, `debutante`, `kids_party`, `corporate`, `barbecue`, `graduation` |
| Comodidade | o que o espaço oferece (Wi-Fi, cozinha...) | `amenities`; rótulos em `catalog_presentation.dart` |
| "A partir de" | o preço inicial informado pelo fornecedor, quando o valor é fixo | `price_from_cents`, com `pricing_model` `fixed` |
| Modelo de preço | a que o preço se refere: o serviço inteiro, cada pessoa, cada hora, cada unidade, ou sob consulta | `PricingModel` |
| Sob consulta | anúncio ou serviço sem preço publicado; nunca aparece como um número | `PricingModel.onRequest`, `on_request` |
| Serviço próprio | o que o anunciante oferece junto com o anúncio (o buffet do salão); pode ser obrigatório | `ListingOffer`, tabela `listing_offers` |
| Parceiro | outro anúncio que um anúncio recomenda; é contratado à parte | `ListingDetail.partners`, tabela `listing_partners` |
| Vitrine | as faixas de anúncios da tela inicial | `HomeController`, `HomeSection` |
| Favorito | anúncio guardado pela conta | `FavoritesController`, tabela `favorites` |
| Festa | o evento que a pessoa está compondo: nome, tipo, data, convidados e os itens escolhidos | `Party` (agregado) |
| Party Maker | a funcionalidade de compor e gerenciar um evento; é a aba central | `features/party_maker` |
| Item da festa | um anúncio (ou um serviço próprio de um anúncio) colocado na festa: a cópia do catálogo, o que a pessoa configurou e o que o fornecedor respondeu | `PartyItem` |
| Configuração do item | o que a categoria pede para o item entrar: a duração de um salão, o tema de uma decoração | `ItemConfiguration`; a tabela é `ItemConfigurationSpec` (app) e `_SPECS` (API) |
| Estimativa | a conta que o app faz com o preço do anúncio e o que a pessoa informou. Não é o preço | `Pricing.estimate`, `BudgetEstimate`; `estimate_cents` |
| Orçamento | o valor que cada fornecedor respondeu para o item dele. Nunca se confunde com a estimativa | `ItemQuote`; `quoted_cents` |
| Solicitar orçamento | congelar a festa e mandar cada item para o fornecedor dele | `Party.requestQuote`; status `locked` |
| Pedido de orçamento | um item de uma festa, como o fornecedor o vê | `QuoteRequest`; `GET /vendors/me/quote-requests` |
| Edição solicitada | um fornecedor pediu uma alteração em um item, ou não pode atender | status `edit_requested`; `QuoteStatus.changesRequested`, `declined` |
| Rodada | cada vez que o orçamento de uma festa é pedido; a segunda em diante é um reenvio | `Party.quoteRound`; `quote_round` |
| Editar festa | voltar ao planejamento uma festa com o orçamento solicitado | `Party.reopenForEditing` |
| Orçamento aceito | a pessoa aceitou o que os fornecedores responderam. Não reserva nem cobra | status `confirmed` |
| Fornecedor | conta que pediu para anunciar | `VendorProfile` |
| Cadastro de fornecedor | os dados de quem anuncia (CPF/CNPJ e nome), enviados com o primeiro anúncio | `POST /vendors/onboarding` |
| Fila de análise | cadastros e anúncios esperando decisão | `ReviewQueue`, rotas `/admin/*` |
| Modo Cliente / Modo Fornecedor | os dois jeitos de ver a aba Perfil | `_vendorMode` em `profile_page.dart` |
| "Em breve" | função prevista e ainda não construída | itens de menu sem `onTap` |

## Técnica

| Termo | Significado | No código |
|---|---|---|
| Modo demonstração | o app sem API, com dados em memória | `AppConfig.isDemoMode`, `AppDependencies.demo` |
| Raiz de composição | o único lugar que escolhe as implementações | `lib/app/app_dependencies.dart` |
| Contrato | a interface que as telas conhecem | `*Repository` em `domain/` |
| Falha | erro traduzido para um texto que a tela pode mostrar | `AppFailure` e subclasses |
| Estado desejado | a festa como o app quer gravá-la, enviada inteira | `PUT /parties/{id}`, `partyToJson` |
| Versão | contador que detecta gravação concorrente da festa | `parties.version` |
| Snapshot | cópia de um dado no momento em que foi usado | nome e preço do item; a estimativa de quando o orçamento foi solicitado (`party_snapshots`) |
| Token de acesso | credencial curta de cada chamada (15 min) | JWT |
| Token de renovação | credencial longa que troca o par de tokens | tabela `refresh_tokens` (só o hash) |
| Família | os tokens de renovação nascidos do mesmo login | `refresh_tokens.family_id` |
| Cofre do sistema | onde o aparelho guarda segredos | `flutter_secure_storage` (Keystore, Keychain) |
| Token de design | cor, espaçamento ou estilo com nome | `AppPalette` (por `context.colors`), `AppColors`, `AppSpacing`, `AppTypography` (por `context.text`) |
| Tema | o conjunto de cores em uso: claro ou escuro | `AppTheme.light()`, `AppTheme.dark()`; a escolha fica em `ThemeModeController` |
| Knowledge Base, cofre | esta pasta `docs/`, que o Obsidian abre como cofre | [memory-system](memory-system.md) |
