---
title: Telas e navegação
type: ux
updated: 2026-10-02
---

# Telas e navegação

## Mapa

```
Barra inferior (app_shell.dart)
├── Início ─────────────── busca ▸ Busca
│                          ♥ ▸ Favoritos
│                          sino ▸ Notificações (vazia)
│                          categoria ▸ aba Explorar com o filtro
├── Explorar
├── ● Minhas festas* ───── hub Minhas Festas ⇄ Montagem da festa
├── Chat ───────────────── "Conversas em breve"
└── Perfil* ────────────── Dados Pessoais
                           Formas de Pagamento ("em breve")
                           Favoritos
                           Aparência (tema claro, escuro ou o do aparelho)
                           Segurança ▸ Alterar senha · Excluir conta
                           Termos e Política ▸ Termos de Uso · Política de Privacidade
                           Fornecedor: Convite ▸ O que anunciar ▸ Formulário do salão
                           Administração**: Fila de análise

De qualquer card de anúncio:  + ▸ folha "Em qual festa?" ▸ diálogo "Nome da nova festa"
Onde uma conta é exigida:     Entrar ⇄ Criar conta
```

`*` exige conta: para visitante a aba mostra um convite a entrar. Na aba
Perfil o convite traz também o atalho para **Aparência**, que não depende de
conta.
`**` só para administradores.

## Capturas

Geradas das telas reais por `test/visual/screenshots_test.dart`, em modo
demonstração, com a fonte Inter embutida e as sombras de verdade (nos testes
o Flutter troca cada sombra por um contorno escuro; `withRealShadows`, em
`test/support/visual_harness.dart`, desliga isso só para as capturas). Para
regenerar:

```
flutter test --update-goldens --run-skipped --tags screenshots test/visual/screenshots_test.dart
```

O teste passa por todas as telas duas vezes, uma em cada tema. Do tema
escuro ficam no repositório só as telas da tabela abaixo; para ver as outras,
acrescente `--dart-define=ALL_DARK=true` e elas saem em
`build/screenshots-escuro/`, que não é versionada.

| Tela | Arquivo em `docs/screenshots/` | No tema escuro |
|---|---|---|
| Início | `home.png` | `home-escuro.png` |
| Explorar | `explorar.png` | `explorar-escuro.png` |
| Busca com resultados | `busca.png` | |
| Favoritos | `favoritos.png` | |
| Folha "Em qual festa?" | `adicionar-a-festa.png` | |
| Montagem da festa | `party-maker.png` | `party-maker-escuro.png` |
| Minhas Festas (com orçamento solicitado) | `minhas-festas.png` | |
| Perfil (com conta) | `perfil.png` | `perfil-escuro.png` |
| Perfil (visitante) | `perfil-visitante.png` | |
| Dados Pessoais | `dados-pessoais.png` | |
| Aparência | `aparencia.png` | `aparencia-escuro.png` |
| Entrar | `entrar.png` | `entrar-escuro.png` |
| Criar conta | `criar-conta.png` | |
| Convite ao fornecedor | `fornecedor-convite.png` | a tela é escura nos dois temas; só o botão muda de tom |
| O que você vai anunciar? | `fornecedor-categorias.png` | |
| Formulário do salão, com erros de validação | `fornecedor-validacao.png` | `fornecedor-validacao-escuro.png` |
| Termos de Uso | `termos-de-uso.png` | |
| Fila de análise: fornecedores | `admin-fornecedores.png` | `admin-fornecedores-escuro.png` |
| Fila de análise: anúncios | `admin-anuncios.png` | |

Mudou uma tela que tem captura → regenere e envie as imagens junto.

## Telas sem captura

Segurança, Alterar senha, Política de Privacidade, Formas de Pagamento, Chat,
Notificações, e a tela de erro de configuração (`ConfigErrorApp`, mostrada
quando `API_BASE_URL` é inválida).
