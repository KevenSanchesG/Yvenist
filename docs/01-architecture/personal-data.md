---
title: Inventário de dados pessoais
type: architecture
updated: 2026-10-02
---

# Inventário de dados pessoais

O que o app e a API coletam, guardam e mandam para fora, **como está no
código**. É a base técnica da Política de Privacidade
([legal](../03-features/legal.md)), da ficha "Segurança dos dados" da Play
Store e da revisão por um advogado. Não é um parecer jurídico: o que é dado
pessoal, a base legal e os prazos são decisões de quem assina os textos.

Levantado em 2 de outubro de 2026 lendo os modelos (`models.py` de cada módulo
em `backend/app/modules/`), os contratos (`schemas.py`), o log
(`backend/app/core/logging.py`), o cliente HTTP do app
(`lib/core/network/api_client.dart`), o cofre de tokens, o `pubspec.yaml` e os
manifestos do Android e do iOS.

## O que é guardado no servidor

| Dado | Onde | De onde vem | Obrigatório | Usado para | Quem vê |
|---|---|---|---|---|---|
| E-mail | `users.email` | cadastro | sim | entrar na conta | a própria conta |
| Senha | `users.password_hash` (Argon2id; a senha não é guardada) | cadastro | sim | entrar na conta | ninguém |
| Nome completo | `users.full_name` | cadastro; Dados Pessoais | sim | mostrar no perfil | a própria conta |
| Telefone | `users.phone` | Dados Pessoais | não | **nenhuma função usa** | a própria conta |
| Data de nascimento | `users.birth_date` | Dados Pessoais | não | **nenhuma função usa** | a própria conta |
| Aceite dos termos | `users.terms_version`, `terms_accepted_at` | cadastro | sim | registro do aceite | ninguém (só no banco) |
| Sessões | `refresh_tokens`: hash do token, `user_agent` (até 255 caracteres), abertura, validade, encerramento | cada login | sim | manter a sessão; detectar reuso de token | a própria conta (`GET /users/me/sessions`) |
| Favoritos | `favorites` | botão de favoritar | não | lista de favoritos | a própria conta |
| Festas | `parties`, `party_items`, `party_snapshots`: nome, data, convidados, itens, orçamento | Party Maker | não | montar a festa | a própria conta |
| Tipo de pessoa, CPF ou CNPJ, nome ou razão social | `vendor_profiles` | cadastro de fornecedor | sim, para anunciar | verificar quem anuncia | a conta vê o documento mascarado; **administradores veem o número completo** |
| Resultado da análise | `vendor_profiles` e `listings`: situação, motivo da recusa, data, quem analisou | fila de análise | — | informar o fornecedor | a conta dona (sem o nome de quem analisou); administradores |
| Anúncio | `listings`: título, descrição, bairro, cidade, UF, preço, capacidade, área, estrutura, cancelamento, URL da capa | cadastro de salão | sim, para anunciar | catálogo | **qualquer pessoa**, depois de publicado |
| Datas de criação e alteração | `created_at`, `updated_at` de cada tabela | automático | — | ordenação e histórico | a própria conta, em parte |

O anúncio público **não** leva o nome nem o documento de quem anuncia
(`ListingSummary` e `ListingDetail`, em `catalog/schemas.py`). Administradores
não recebem e-mail nem telefone de ninguém pela fila (`AdminVendorResponse`).

## O que passa pelo servidor e não é guardado

| Dado | O que acontece |
|---|---|
| Endereço IP | fica na memória do limitador por um minuto, nas rotas de cadastro, login, renovação da sessão, troca de senha e exclusão da conta (`core/rate_limit.py`, `accounts/router.py`). Não vai para o log **se** o servidor rodar com `--no-access-log`, como no `backend/Dockerfile` ([deployment](../09-guides/deployment.md)) |
| Texto da busca e filtros | usados para responder e descartados. O log guarda método, caminho, status e duração, **sem** a query string |
| Senha | conferida e descartada; nunca entra em log nem em resposta de erro |

## O que fica no aparelho

| Dado | Onde |
|---|---|
| Tokens da sessão | cofre do sistema: Keystore no Android, Keychain no iOS (`lib/core/storage/token_storage.dart`). Na web, `localStorage` ([KI-30](../07-known-issues/README.md)) |
| A escolha de tema (`system`, `light` ou `dark`) | no mesmo lugar, pela chave `yvenist.theme_mode` (`lib/core/storage/theme_preference_storage.dart`). É do aparelho, e não da conta: **não vai para o servidor**, não é apagada ao sair nem ao excluir a conta, e vale para quem não entrou. Não identifica ninguém |
| Mais nada | o app não tem banco local nem cache em disco (dependências em `pubspec.yaml`: `http`, `flutter_secure_storage`, `provider`, `intl`) |

O backup do Google está desligado no Android (`android:allowBackup="false"`).
No iOS, se os tokens entram em um backup do aparelho não foi conferido
([KI-40](../07-known-issues/README.md)).

## Para quem os dados saem

| Destino | O quê | Observação |
|---|---|---|
| A API do Yvenist | tudo da primeira tabela | por `https` em um build de release |
| O servidor de cada imagem de anúncio | o IP do aparelho e o que todo pedido de imagem leva | a URL da capa é a que o fornecedor informou; o Yvenist não hospeda imagens |
| Hospedagem e banco | tudo o que a API guarda | OPEN QUESTION: ainda não existe ([roadmap](../00-project/roadmap.md)) |
| Na versão web, `gstatic.com` (Google) | o IP do navegador | o build web baixa de lá o motor de desenho do Flutter e fontes de reserva (visto no build local, em `flutter_bootstrap.js`). A versão web não é publicada |

Não há SDK de publicidade, de análise de uso, de registro de falhas nem de
notificações. Nenhum dado é enviado a terceiros pelo código.

## O que não é coletado

| O quê | Como foi conferido |
|---|---|
| Localização, contatos, câmera, fotos, microfone | o manifesto do Android pede só `INTERNET` (`android/app/src/main/AndroidManifest.xml`); o `ios/Runner/Info.plist` não tem nenhuma descrição de uso |
| Dados de pagamento | não há pagamento no código |
| Identificador do aparelho ou de publicidade | nenhuma dependência o lê. O `user_agent` gravado é o que o cliente HTTP manda sozinho: no celular, o nome e a versão da biblioteca; na web, o do navegador |
| Mensagens, avaliações | as funções não existem |

## Exclusão

`POST /users/me/delete`, com a senha (`accounts/service.py`), apaga a linha da
conta, e o banco apaga em cascata sessões, favoritos, festas, cadastro de
fornecedor e anúncios ([data-model](data-model.md)). É imediata e definitiva.

O que sobra: a cópia de nome, preço e imagem de um anúncio que já estava na
festa de outra pessoa (`party_items`, sem ligação com o fornecedor), e o que
estiver em cópias de segurança (OPEN QUESTION: não há política de cópias).

Sessões vencidas ou encerradas ficam no banco até alguém rodar
`purge-tokens`: não há rotina automática.

## Os textos conferem com o código?

Conferido linha a linha em 2 de outubro de 2026. O que divergia foi corrigido
nos próprios textos, sempre mantendo o rótulo de versão preliminar:

| Achado | O que foi feito |
|---|---|
| A política não citava o tipo de pessoa do fornecedor, o resultado da análise nem as datas de criação e alteração | acrescentados à seção 2 |
| A política dizia que o IP é usado ao "entrar ou criar conta"; o limite vale também ao renovar a sessão, trocar a senha e excluir a conta | seção 2 corrigida |
| Os dois textos prometem avisar "pelo aplicativo" quando mudarem, e o aviso não existe ([KI-26](../07-known-issues/README.md)) | trecho marcado entre colchetes nos dois |
| Os dois dizem "18 anos ou mais", e o app não pergunta nem confere a idade | acrescentado ao colchete que já pedia confirmação |
| Não havia como pedir a exclusão sem o app, que a Play Store exige | frase na seção 7 da política e a página `deploy/site/exclusao-de-conta.md` |
| "A sessão fica no cofre seguro do aparelho" não vale para a versão web | mantido: a versão web não é publicada. Rever junto com o KI-30 |
| O app passou a guardar a escolha de tema no aparelho | frase acrescentada à seção 2 da política, no mesmo dia em que a função entrou |

## Perguntas que o levantamento deixa

Estão no [roadmap](../00-project/roadmap.md) e em
[legal](../03-features/legal.md). As que nasceram aqui:

- OPEN QUESTION: para que servem o telefone e a data de nascimento? Nenhuma
  função os usa. Ou ganham finalidade, ou saem do formulário
  ([KI-19](../07-known-issues/README.md)).
- OPEN QUESTION: a idade mínima vale só como declaração ao aceitar os termos,
  ou o app deve perguntar a data de nascimento no cadastro?
- OPEN QUESTION: por quanto tempo ficam as cópias de segurança, e quem é o
  provedor de hospedagem (e em que país)?

## Apoio para a ficha "Segurança dos dados" da Play Store

`[INFERÊNCIA]` Leitura do código à luz das definições do Google (conferidas em
2 de outubro de 2026 na ajuda do Play Console). Quem responde a ficha são os
donos.

| Tipo de dado da ficha | Coletado? | Obrigatório | Finalidade na ficha |
|---|---|---|---|
| Nome | sim | sim | gerenciamento da conta |
| Endereço de e-mail | sim | sim | gerenciamento da conta |
| IDs de usuário (o id da conta) | sim | sim | funcionalidade do app |
| Número de telefone | sim | não | gerenciamento da conta |
| Outras informações (data de nascimento; CPF ou CNPJ de quem anuncia) | sim | não | gerenciamento da conta; prevenção de fraude e segurança |
| Outro conteúdo gerado pelo usuário (festas, anúncios) | sim | não | funcionalidade do app |
| Outras ações (favoritos) | sim | não | funcionalidade do app |
| Histórico de pesquisa no app | não: usado e descartado | — | — |
| Localização, fotos, dados financeiros, IDs do aparelho, registros de falha | não | — | — |

- Compartilhado com terceiros: não.
- Criptografado em trânsito: sim, em builds de release.
- Exclusão: pelo app, e pela página pública de exclusão de conta
  ([legal](../03-features/legal.md)).
- O endereço IP fica um minuto em memória para limitar tentativas. Se isso é
  "coleta" na definição da ficha é uma decisão de quem a preenche.
- A escolha de tema fica só no aparelho. `[INFERÊNCIA]` Pela definição da
  ficha, o que não sai do aparelho não é dado coletado.
