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
                           Segurança ▸ Alterar senha · Excluir conta
                           Termos e Política ▸ Termos de Uso · Política de Privacidade
                           Fornecedor: Convite ▸ O que anunciar ▸ Formulário do salão
                           Administração**: Fila de análise

De qualquer card de anúncio:  + ▸ folha "Em qual festa?" ▸ diálogo "Nome da nova festa"
Onde uma conta é exigida:     Entrar ⇄ Criar conta
```

`*` exige conta: para visitante a aba mostra um convite a entrar.
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

| Tela | Arquivo em `docs/screenshots/` |
|---|---|
| Início | `home.png` |
| Explorar | `explorar.png` |
| Busca com resultados | `busca.png` |
| Favoritos | `favoritos.png` |
| Folha "Em qual festa?" | `adicionar-a-festa.png` |
| Montagem da festa | `party-maker.png` |
| Minhas Festas (com orçamento solicitado) | `minhas-festas.png` |
| Perfil (com conta) | `perfil.png` |
| Perfil (visitante) | `perfil-visitante.png` |
| Dados Pessoais | `dados-pessoais.png` |
| Entrar | `entrar.png` |
| Criar conta | `criar-conta.png` |
| Convite ao fornecedor | `fornecedor-convite.png` |
| O que você vai anunciar? | `fornecedor-categorias.png` |
| Formulário do salão, com erros de validação | `fornecedor-validacao.png` |
| Termos de Uso | `termos-de-uso.png` |
| Fila de análise: fornecedores | `admin-fornecedores.png` |
| Fila de análise: anúncios | `admin-anuncios.png` |

Mudou uma tela que tem captura → regenere e envie as imagens junto.

## Telas sem captura

Segurança, Alterar senha, Política de Privacidade, Formas de Pagamento, Chat,
Notificações, e a tela de erro de configuração (`ConfigErrorApp`, mostrada
quando `API_BASE_URL` é inválida).
