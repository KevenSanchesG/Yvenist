---
title: Problemas e limites conhecidos
type: known-issues
updated: 2026-10-03
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
| KI-05 | iOS nunca foi compilado | um Mac com Xcode; a lista do que fazer nele está em [ios-build](../09-guides/ios-build.md) | donos |

## Produto

| # | O quê | Quando incomoda |
|---|---|---|
| KI-11 | Não há página de detalhe do anúncio | a pessoa decide pelo card e pela tela de configuração do item |
| KI-12 | Só salões podem ser cadastrados pelo app, e o cadastro não deixa indicar parceiros | fornecedores de outras categorias ([PM-7](../03-features/party-maker/known-issues.md)) |
| KI-13 | Anúncio sem fotos: a capa é uma URL e o formulário nem a pede | anúncios reais ficam sem imagem |
| KI-14 | Não há como editar, despublicar ou apagar um anúncio | o primeiro fornecedor que errar um dado |
| KI-15 | Notas dos anúncios não têm quem as alimente | os cards mostram nota só nos dados de demonstração |
| KI-16 | Sem recuperar senha nem confirmar e-mail | a primeira pessoa que esquecer a senha |
| KI-19 | Telefone e data de nascimento são pedidos em Dados Pessoais e nenhuma função os usa | a revisão jurídica: a LGPD pede finalidade para cada dado ([personal-data](../01-architecture/personal-data.md)) |
| KI-60 | O Party Maker de 3 de outubro de 2026 tem decisões de negócio tomadas sem os donos: orçamento por item, o que cada categoria pergunta, o que é obrigatório para pedir, o status "orçamento aceito", nenhuma ponta ver quem é a outra | antes de mostrar a usuários reais: os donos precisam confirmar ou mudar ([ADR-019](../05-decisions/ADR-019-festa-como-composicao-de-evento.md), [PM-20 a PM-26](../03-features/party-maker/known-issues.md)) |
| KI-61 | Ninguém é avisado: a resposta de um fornecedor só aparece quando a pessoa atualiza a festa, e o pedido só aparece quando o fornecedor abre a caixa de pedidos | assim que houver usuários reais ([PM-1](../03-features/party-maker/known-issues.md)) |
| KI-62 | Aceitar um orçamento não reserva a data, não gera contrato e não cobra; um orçamento respondido não expira | a primeira festa combinada de verdade pelo app ([PM-3, PM-4](../03-features/party-maker/known-issues.md)) |
| KI-63 | As observações de um item e o recado do fornecedor são texto livre que chega à outra ponta | alguém escrever ali um dado pessoal; a política pede para não escrever, a tela não impede ([personal-data](../01-architecture/personal-data.md)) |

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
| KI-27 | Regras das festas duplicadas no app e na API: o ciclo, a tabela de cada categoria e a conta da estimativa | toda mudança de regra | [PM-10](../03-features/party-maker/known-issues.md) |
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
| KI-44 | O tema escuro em um aparelho de verdade: foi visto nas capturas geradas pelos testes e em um emulador Android 13 |
| KI-45 | As barras do sistema fora do Android 13: o leiaute de borda a borda foi visto só no emulador dessa versão, que é a única imagem instalada. Do Android 15 em diante o sistema impõe o mesmo leiaute; no 9 ou mais antigo vale o clássico ([ADR-018](../05-decisions/ADR-018-tela-inteira-em-qualquer-android.md)) |
| KI-46 | As telas do Party Maker de 3 de outubro de 2026 (dados do evento, configuração do item, a festa com o orçamento, histórico, pedidos de orçamento) em um aparelho ou em um emulador: foram vistas só nas capturas geradas pelos testes, nos dois temas |

## Ambiente de desenvolvimento

| # | O quê | Contorno |
|---|---|---|
| KI-50 | O Controle Inteligente de Aplicativos do Windows bloqueia alguns binários (extensões do SQLAlchemy e do mypy, `psql.exe`) | seção "Windows" de [development](../09-guides/development.md). **Não desligue a proteção** |
| KI-51 | Sem Docker na máquina | a imagem e o `docker compose` são conferidos pelo CI |
| KI-52 | `flutter test --platform chrome` trava no Windows | roda no CI ([flutter-web-testing](../06-research/flutter-web-testing.md)) |
| KI-53 | Sem a ferramenta `gh` | a situação do CI é lida pela API pública do GitHub; o log pede autenticação ([ci](../09-guides/ci.md)) |
| KI-54 | Abrir o Claude Code acima da pasta do repositório não carrega o `CLAUDE.md` na largada | abrir dentro de `Yvenist\` ([claude-code-memory](../06-research/claude-code-memory.md)) |
| KI-55 | A chave de envio do Android existe em uma máquina só, e as senhas dela só em `android/key.properties`, que não é versionado. Apagar a pasta do projeto, ou perder a máquina, leva as senhas junto | **dos donos:** guardar uma cópia do arquivo `.jks` e das duas senhas em um gerenciador de senhas ([android-release](../09-guides/android-release.md)). Antes do primeiro envio à loja, perder a chave só custa criar outra; depois, é preciso pedir a troca ao Google |

## Como registrar um problema

Uma linha na tabela certa, com o próximo número da faixa. Um número que saiu
**não volta a ser usado**: o changelog cita o antigo ("era o KI-10"). A faixa
de produto (KI-10 a KI-19) acabou e continua em KI-60. Se precisar de mais
do que uma linha (passos para reproduzir, análise), crie uma nota a partir de
[`templates/known-issue.md`](../templates/known-issue.md) nesta pasta e
aponte para ela. Resolveu → tire a linha daqui e cite no
[changelog](../08-changelog/README.md).
