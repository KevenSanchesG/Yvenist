---
title: Problemas e limites conhecidos
type: known-issues
updated: 2026-10-02
---

# Problemas e limites conhecidos

Tudo o que se sabe que está quebrado, limitado, não verificado ou pendente. Os
do Party Maker têm lista própria:
[party-maker/known-issues](../03-features/party-maker/known-issues.md).

Como ler: **Quando incomoda** é o gatilho que torna o item urgente. Sem
gatilho, não é para agora.

## Bloqueiam a publicação

| # | O quê | O que falta | De quem |
|---|---|---|---|
| KI-01 | Textos legais são preliminares, com lacunas entre colchetes | revisão jurídica e os dados da empresa ([legal](../03-features/legal.md)) | donos |
| KI-02 | A política de privacidade e a página de exclusão de conta não têm endereço público | escolher onde hospedar as páginas, que já são geradas por `tools/build_legal_site.py` ([legal](../03-features/legal.md)); a Play Store exige as duas | donos |
| KI-03 | A API não está hospedada | escolher e contratar a hospedagem e apontar o endereço da API para ela; a receita com HTTPS está pronta em `deploy/` ([deployment](../09-guides/deployment.md)) | donos |
| KI-04 | Não há chave de envio do Android | criar e guardar fora do repositório; o resto do caminho de assinatura está pronto e é conferido pelo CI ([android-release](../09-guides/android-release.md)) | donos |
| KI-05 | iOS nunca foi compilado | um Mac com Xcode; a lista do que fazer nele está em [ios-build](../09-guides/ios-build.md) | donos |
| KI-06 | A branch não foi mesclada na `main` | decisão | donos |

## Produto

| # | O quê | Quando incomoda |
|---|---|---|
| KI-10 | O orçamento não chega a nenhum fornecedor | assim que houver usuários reais ([PM-1](../03-features/party-maker/known-issues.md)) |
| KI-11 | Não há página de detalhe do anúncio | a pessoa decide só pelo card |
| KI-12 | Só salões podem ser cadastrados pelo app | fornecedores de outras categorias |
| KI-13 | Anúncio sem fotos: a capa é uma URL e o formulário nem a pede | anúncios reais ficam sem imagem |
| KI-14 | Não há como editar, despublicar ou apagar um anúncio | o primeiro fornecedor que errar um dado |
| KI-15 | Notas dos anúncios não têm quem as alimente | os cards mostram nota só nos dados de demonstração |
| KI-16 | Sem recuperar senha nem confirmar e-mail | a primeira pessoa que esquecer a senha |
| KI-17 | O laranja da marca (`#FF6600`) não tem contraste para texto | decisão do tom ([ADR-008](../05-decisions/ADR-008-acessibilidade-e-cores.md)) |
| KI-19 | Telefone e data de nascimento são pedidos em Dados Pessoais e nenhuma função os usa | a revisão jurídica: a LGPD pede finalidade para cada dado ([personal-data](../01-architecture/personal-data.md)) |

## Técnicos

| # | O quê | Quando incomoda | Caminho |
|---|---|---|---|
| KI-20 | Limite de requisições em memória, por processo | mais de uma instância da API | limitar no proxy, ou contador compartilhado |
| KI-21 | Limite de login só por IP | ataque distribuído a uma conta | limite também por conta, sem virar bloqueio da vítima |
| KI-22 | Busca com `LIKE '%termo%'` | dezenas de milhares de anúncios | índice `pg_trgm` ou busca textual do PostgreSQL |
| KI-23 | Renovação estrita: resposta perdida derruba a sessão | redes muito instáveis | janela curta de tolerância para o token anterior |
| KI-24 | Fila de análise limitada a 50, sem paginação | mais de 50 itens pendentes | paginar por cursor |
| KI-25 | A data mostrada na fila é a do primeiro envio do cadastro | cadastros reenviados | expor a data do reenvio |
| KI-26 | Aceite dos termos sem reaceite quando o texto muda; os textos prometem um aviso "pelo aplicativo" que não existe | textos finais e uma mudança relevante | fluxo de reaceite, ou tirar a promessa dos textos |
| KI-27 | Regras das festas duplicadas no app e na API | toda mudança de regra | [PM-9](../03-features/party-maker/known-issues.md) |
| KI-28 | Mensagens de erro espalhadas, sem catálogo; um idioma só | internacionalização | [ADR-009](../05-decisions/ADR-009-erros-uniformes.md) |

## Web

A versão web compila, funciona contra a API e é testada no CI, mas não é
tratada como produto.

| # | O quê | Quando incomoda | Caminho |
|---|---|---|---|
| KI-30 | Os tokens ficam no armazenamento do navegador (`flutter_secure_storage` na web usa `localStorage`) | publicar a versão web | token de renovação em cookie `HttpOnly` |
| KI-31 | Imagens de anúncio dependem de CORS no servidor da imagem | capas hospedadas em qualquer site | hospedar as imagens, ou um proxy |
| KI-32 | `[INFERÊNCIA]` Leiaute desenhado só para celular; nunca foi visto em tela larga (a conferência usou 412×915) | uso em computador | leiaute responsivo |
| KI-33 | O navegador registra como erro o 404 esperado de `GET /vendors/me` | só ruído no console | responder 200 com corpo vazio |

## Não verificado

| # | O quê |
|---|---|
| KI-40 | iOS: nem compilação, nem o comportamento do Keychain em cópias de segurança |
| KI-41 | Leitores de tela reais (TalkBack, VoiceOver): só as verificações de semântica dos testes |
| KI-42 | Build de release contra uma API em `https` de verdade; a receita de `deploy/` em um servidor, com certificado emitido de verdade |
| KI-43 | Carga: nenhum teste de desempenho |

## Ambiente de desenvolvimento

| # | O quê | Contorno |
|---|---|---|
| KI-50 | O Controle Inteligente de Aplicativos do Windows bloqueia alguns binários (extensões do SQLAlchemy e do mypy, `psql.exe`) | seção "Windows" de [development](../09-guides/development.md). **Não desligue a proteção** |
| KI-51 | Sem Docker na máquina | a imagem e o `docker compose` são conferidos pelo CI |
| KI-52 | `flutter test --platform chrome` trava no Windows | roda no CI ([flutter-web-testing](../06-research/flutter-web-testing.md)) |
| KI-53 | Sem a ferramenta `gh` | a situação do CI é lida pela API pública do GitHub; o log pede autenticação ([ci](../09-guides/ci.md)) |
| KI-54 | Abrir o Claude Code acima da pasta do repositório não carrega o `CLAUDE.md` na largada | abrir dentro de `Yvenist\` ([claude-code-memory](../06-research/claude-code-memory.md)) |

## Como registrar um problema

Uma linha na tabela certa, com o próximo número da faixa. Se precisar de mais
do que uma linha (passos para reproduzir, análise), crie uma nota a partir de
[`templates/known-issue.md`](../templates/known-issue.md) nesta pasta e
aponte para ela. Resolveu → tire a linha daqui e cite no
[changelog](../08-changelog/README.md).
