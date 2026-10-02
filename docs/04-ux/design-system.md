---
title: Design system
type: ux
updated: 2026-10-02
---

# Design system

Cores, tipografia e componentes são **tokens** em `lib/core/theme/`. Uma tela
não escreve cor nem tamanho de fonte à mão. Motivos:
[ADR-008](../05-decisions/ADR-008-acessibilidade-e-cores.md).

## Cores (`app_colors.dart`)

| Token | Valor | Uso |
|---|---|---|
| `primary` | `#FF6600` | **só ícones e áreas grandes**: contraste 2,94:1 sobre branco, insuficiente para texto |
| `primaryStrong` | `#C2410C` | texto laranja, links, botões, rótulo da aba ativa, controles do Material, borda do campo em foco |
| `vendor`, `vendorAccent` | `#2C3E50`, `#3A7D88` | modo fornecedor |
| `clientGradient`, `vendorGradient`, `successGradient` | pares escuros | cabeçalhos e banners com texto branco |
| `textPrimary` | `#333333` | texto |
| `textSecondary` | `#4B5563` | texto de apoio |
| `textTertiary`, `searchPlaceholder`, `navIconInactive` | `#6B7280` | só sobre branco |
| `headerBackground` | `#F2F3F4` | faixa do topo, caixas de aviso neutras |
| `divider` | `#E5E7EB` | linhas e bordas |
| `success`, `danger`, `warning` | `#15803D`, `#B91C1C`, `#92400E` | estados; servem como cor de texto |
| `AppColors.tint(cor)` | a cor a 8% | fundo de aviso ou de item selecionado |

OPEN QUESTION (dos donos): o tom do laranja da marca. Enquanto for `#FF6600`,
ele não pode ser cor de texto.

## Tema (`app_theme.dart`)

- Material 3. O esquema nasce do laranja (`ColorScheme.fromSeed`), mas **toda
  cor que um componente usa sozinho é trocada por um token do app**: as
  derivadas saem marrons e rosadas, e destoam do resto.

  | Papel do Material | Token | Onde aparece |
  |---|---|---|
  | `primary` | `primaryStrong` | caixa de seleção, opção marcada, dia escolhido no calendário, rótulo e cursor do campo em foco |
  | `primaryContainer`, `secondaryContainer` | `tint(primaryStrong)` sobre branco | segmento escolhido de um botão segmentado, filtro marcado: o mesmo destaque do seletor de modo do perfil |
  | `onPrimaryContainer`, `onSecondaryContainer` | `primaryStrong` | texto e visto do item selecionado |
  | `surface` e `surfaceContainer*` | branco, `headerBackground`, `divider` | cartões, menus, listas suspensas, calendário |
  | `onSurface`, `onSurfaceVariant` | `textPrimary`, `textSecondary` | rótulo de campo e de filtro, itens de menu, calendário |
  | `outline` | `textTertiary` | contorno de um controle (botão segmentado, botão com contorno): 4,8:1 |
  | `outlineVariant` | `divider` | contorno decorativo (filtros) |
  | `inverseSurface`, `onInverseSurface` | `textPrimary`, branco | aviso (SnackBar) |

  Papel novo em uso → entra nessa lista e em `test/core/theme_contrast_test.dart`.
- Botão preenchido: `primaryStrong` com texto branco, 52 de altura, cantos
  totalmente arredondados.
- Campos: fundo branco, borda `divider`, raio 12; em foco, borda de 2 em
  `primaryStrong`; erro em `danger`.
- Diálogos, folhas, menus e calendário: brancos.
- Barra de status clara por padrão; sobre o cabeçalho escuro do perfil,
  `AppTheme.systemUiOnDarkHeader`.

## Tipografia (`app_typography.dart`)

Inter 4.1, **embutida** (`assets/fonts`), pesos 400, 500, 600 e 700. A licença
(OFL) vai junto e aparece em "Licenças de código aberto" (`core/licenses.dart`).

| Estilo | Tamanho / peso |
|---|---|
| `sectionTitle` | 18 / 700 |
| `cardTitle` | 16 / 700 |
| `body` | 14 / 400 |
| `caption`, `sectionSubtitle`, `cardLocation` | 12 / 400 |
| `categoryLabel`, `cardRatingScore` | 12 / 700 |
| `navLabel` | 11 / 500 |
| `cardPrice` | 11 / 700, branco |

Nenhum estilo fica abaixo de 11.

## Espaçamento

`AppSpacing` (em `app_colors.dart`): `minTouchTarget = 48`,
`navButtonOverlap = 19` (o quanto o botão central sobe acima da barra).

## Componentes compartilhados (`lib/core/widgets/`)

| Componente | Para quê |
|---|---|
| `LoadingView` | carregando, anunciado por leitor de tela |
| `EmptyStateView` | estado vazio: ícone, título, explicação e, se houver, o próximo passo |
| `ErrorStateView` | erro com "Tentar novamente" |
| `showAppSnackBar` | aviso curto, substituindo o anterior |
| `PrimaryButton` | botão principal de formulário; desabilita e mostra progresso enquanto envia |
| `FormErrorBanner` | erro de formulário, anunciado assim que aparece |
| `PasswordField` | senha com mostrar/ocultar e erro do servidor |
| `AppNetworkImage` | imagem de rede com substituto enquanto carrega ou se falhar |

Do app inteiro: `AppBottomNavBar` e `PartyTabButton` (`lib/app/widgets/`).

## Padrões de tela

- Fundo branco; na aba Perfil e na fila de análise, cinza muito claro com
  cartões brancos.
- Cartão: branco, raio 12 a 16, borda `divider` ou sombra leve.
- Função prevista e não construída: item visível, com "Em breve" no lugar da
  seta, sem responder ao toque.
- Botão que não pode agir fica desabilitado.
- Item selecionado: fundo `tint(primaryStrong)`, texto em `primaryStrong` e um
  visto. Em um filtro com ícone, o visto ocupa o lugar do ícone
  (`explore_page.dart`).
- Ação destrutiva: texto em `danger` e confirmação.
- Toda lista longa tem carregando, vazio e erro.
