---
title: Design system
type: ux
updated: 2026-10-02
---

# Design system

Cores, tipografia e componentes são **tokens** em `lib/core/theme/`. Uma tela
não escreve cor nem tamanho de fonte à mão. O app tem dois temas, claro e
escuro, com os mesmos papéis de cor. Motivos:
[ADR-017](../05-decisions/ADR-017-um-laranja-e-tema-escuro.md).

## Como uma tela pega as cores

```dart
final colors = context.colors; // AppPalette do tema em uso
final text = context.text;     // estilos de texto, já na cor do tema

Text('Título', style: text.sectionTitle);
Icon(Icons.favorite, color: colors.primary);
```

| Arquivo | O que tem |
|---|---|
| `app_palette.dart` | `AppPalette`: as cores que mudam com o tema; `AppPalette.light` e `AppPalette.dark` |
| `app_colors.dart` | `AppColors`: o que é igual nos dois temas (a marca, degradês, película sobre foto) e `AppSpacing` |
| `app_typography.dart` | `AppTypography`: os estilos de texto, montados a partir de uma paleta |
| `app_theme.dart` | `AppTheme.light()` e `AppTheme.dark()`; a extensão `context.colors` / `context.text` |
| `theme_mode_controller.dart` | `ThemeModeController`: o tema que a pessoa escolheu |

Uma cor escrita à mão (`Color(0x…)`, `Colors.white`) fora de `lib/core/theme/`
faz `test/core/theme_usage_test.dart` falhar: ela valeria para um tema só.

## Paleta (`app_palette.dart`)

| Papel | Claro | Escuro | Uso |
|---|---|---|---|
| `primary` | `#C2410C` | `#FB8656` | o laranja da marca: a cor de ação. Texto, link, ícone, botão, aba ativa, controles |
| `onPrimary` | `#FFFFFF` | `#2A1206` | o que vai sobre um fundo `primary` (texto de botão, selo de preço) |
| `background` | `#FFFFFF` | `#121416` | fundo das telas |
| `backgroundMuted` | `#FAFAFA` | `#0C0D0F` | fundo das telas feitas de cartões (perfil, fila de análise) |
| `surface` | `#FFFFFF` | `#1C1F23` | cartões, campos, folhas, diálogos, barras |
| `surfaceMuted` | `#F2F3F4` | `#272B30` | faixas e avisos neutros |
| `divider` | `#E5E7EB` | `#343A41` | linhas e bordas decorativas |
| `outline` | `#6B7280` | `#8B93A1` | contorno que delimita um controle (3:1 ou mais) |
| `textPrimary` | `#333333` | `#F3F4F6` | texto |
| `textSecondary` | `#4B5563` | `#C9CED6` | texto de apoio; legível em qualquer fundo |
| `textTertiary` | `#6B7280` | `#9BA3AF` | texto e ícones discretos; **não** sobre `surfaceMuted` |
| `success`, `danger`, `warning` | `#15803D`, `#B91C1C`, `#92400E` | `#4ADE80`, `#F87171`, `#FBBF24` | estados; servem como cor de texto |
| `vendor` | `#2C3E50` | `#8EC7D2` | modo fornecedor, como texto e destaque |
| `shadow` | preto a 10% | preto a 40% | sombras |

Derivados, para a tela não fazer a conta:

| Derivado | O que é |
|---|---|
| `tint(cor)` | a cor a 8% (claro) ou 16% (escuro): fundo de aviso ou de item selecionado. Só sobre `background` e `surface` |
| `selectedSurface` | `tint(primary)` já misturado com `surface`: o fundo de um item selecionado, opaco |
| `headerBand` | a faixa do topo da tela inicial: `surfaceMuted` no claro, `surface` no escuro |
| `raisedSurface` | um controle por cima de uma faixa, de um cartão ou de uma foto (a busca e os atalhos do início, os botões redondos dos anúncios): `surface` no claro, `surfaceMuted` no escuro |
| `isDark` | para o que muda de forma, e não só de cor (borda no lugar de sombra) |

Iguais nos dois temas (`app_colors.dart`):

| Token | Valor | Uso |
|---|---|---|
| `brand`, `brandOnDark` | `#C2410C`, `#FB8656` | os dois valores de `primary`. `brandOnDark` também nos lugares que são sempre escuros |
| `clientGradient`, `vendorGradient`, `successGradient` | pares escuros | cabeçalho do perfil e banners, com texto branco |
| `onGradient` | branco | texto e ícones sobre os degradês e sobre foto escurecida |
| `photoScrim` | preto a 70% | película sobre a foto do convite ao fornecedor |

## Como o tema escuro foi desenhado

`[DECISÃO]` Não é o tema claro invertido
([ADR-017](../05-decisions/ADR-017-um-laranja-e-tema-escuro.md)):

- **Fundo cinza muito escuro**, e não preto. Texto claro sobre preto puro tem
  contraste demais e cansa em leitura longa.
- **Profundidade por claridade.** No claro, um cartão se destaca pela sombra.
  No escuro a sombra não se vê: o cartão é mais claro que o fundo e ganha uma
  borda (`divider`). Vale para os cards de anúncio, os itens da festa, a barra
  inferior e os rodapés fixos.
- **Destaques mais claros.** O laranja e as cores de estado sobem de tom para
  manter o contraste; o texto sobre o botão laranja passa a ser escuro.
- **Seleção mais forte.** O fundo de um item selecionado usa 16% da cor,
  contra 8% no claro: um tom suave some sobre fundo escuro.

## O laranja é a cor de ação

`[DECISÃO]` Um tom só por tema. Ele aparece no que a pessoa pode tocar (botão,
link, ícone de ação), no que está selecionado (aba ativa, filtro marcado) e no
preço. Texto corrido, títulos e fundos são neutros: se tudo fosse laranja,
nada se destacaria. Vermelho (`danger`) é só para erro e ação destrutiva;
verde (`success`), para o que deu certo; âmbar (`warning`), para o que está
em análise.

## Tema (`app_theme.dart`)

- Material 3. O esquema nasce do laranja (`ColorScheme.fromSeed`), mas **toda
  cor que um componente usa sozinho é trocada por um token da paleta**: as
  derivadas saem marrons e rosadas, e destoam do resto.

  | Papel do Material | Token | Onde aparece |
  |---|---|---|
  | `primary`, `onPrimary` | `primary`, `onPrimary` | caixa de seleção, opção marcada, dia escolhido no calendário, rótulo e cursor do campo em foco |
  | `primaryContainer`, `secondaryContainer` | `selectedSurface` | segmento escolhido de um botão segmentado, filtro marcado: o mesmo destaque do seletor de modo do perfil |
  | `onPrimaryContainer`, `onSecondaryContainer` | `primary` | texto e visto do item selecionado |
  | `surface` e `surfaceContainer*` | `surface`, `surfaceMuted`, `divider` | cartões, menus, listas suspensas, calendário |
  | `onSurface`, `onSurfaceVariant` | `textPrimary`, `textSecondary` | rótulo de campo e de filtro, itens de menu, calendário |
  | `outline` | `outline` | contorno de um controle (botão segmentado, botão com contorno) |
  | `outlineVariant` | `divider` | contorno decorativo (filtros) |
  | `inverseSurface`, `onInverseSurface`, `inversePrimary` | `textPrimary`, `background`, o laranja do outro tema | aviso (SnackBar), com as cores invertidas |
  | `error` | `danger` | mensagem de erro dos campos |

  Papel novo em uso → entra nessa lista e em `test/core/theme_contrast_test.dart`.
- Botão preenchido: `primary` com texto `onPrimary`, 52 de altura, cantos
  totalmente arredondados.
- Campos: fundo `surface`, borda `divider`, raio 12; em foco, borda de 2 em
  `primary`; erro em `danger`.
- Diálogos, folhas, menus e calendário: `surface`.
- Barra de status: ícones escuros no tema claro e claros no escuro
  (`AppTheme.systemUi`). Onde o topo da tela é escuro nos dois temas (o
  cabeçalho do perfil, o convite ao fornecedor), `AppTheme.systemUiOnDarkHeader`.

## Escolha do tema

Perfil → Configurações e suporte → **Aparência**
(`lib/features/shared_features/appearance/presentation/pages/appearance_page.dart`).
Para quem não entrou em uma conta, a aba Perfil mostra um atalho "Aparência"
abaixo do convite a entrar (`lib/app/app_shell.dart`).

| Opção | O que faz |
|---|---|
| Padrão do aparelho | acompanha o tema do sistema. É o valor inicial |
| Claro | sempre claro |
| Escuro | sempre escuro |

- A troca vale na hora, sem botão de salvar: a própria tela é a prévia. As
  cores passam de um tema para o outro com a animação do Material
  (`AppPalette.lerp`).
- A escolha é **do aparelho, e não da conta**: continua valendo depois de sair
  da conta e depois de fechar o app. `ThemeModeController` (em `AppState`) a
  guarda por `ThemePreferenceStorage`
  (`lib/core/storage/theme_preference_storage.dart`), na chave
  `yvenist.theme_mode`, e a lê antes da primeira tela (`lib/main.dart`), para
  o app não piscar no outro tema.
- Se o aparelho falhar ao ler, o app abre no tema do sistema; se falhar ao
  gravar, a escolha vale até o app fechar. Nenhuma das duas falhas impede o
  app de abrir.

Testes: `test/core/theme_mode_test.dart`, `test/app/appearance_flow_test.dart`.

## Tipografia (`app_typography.dart`)

Inter 4.1, **embutida** (`assets/fonts`), pesos 400, 500, 600 e 700. A licença
(OFL) vai junto e aparece em "Licenças de código aberto" (`core/licenses.dart`).

| Estilo | Tamanho / peso | Cor |
|---|---|---|
| `sectionTitle` | 18 / 700 | `textPrimary` |
| `cardTitle` | 16 / 700 | `textPrimary` |
| `body` | 14 / 400 | `textPrimary` |
| `headerSearch` | 14 / 700 | `textTertiary` |
| `caption`, `sectionSubtitle`, `cardRatingCount` | 12 / 400 | `textSecondary` |
| `cardLocation` | 12 / 400 | `textTertiary` |
| `categoryLabel`, `cardRatingScore` | 12 / 700 | `textPrimary` |
| `cardPrice` | 11 / 700 | `onPrimary` |
| `navLabel` | 11 / 500 | quem usa escolhe (aba ativa ou não) |

Nenhum estilo fica abaixo de 11.

## Espaçamento

`AppSpacing` (em `app_colors.dart`): `minTouchTarget = 48`,
`navButtonOverlap = 19` (o quanto o botão central sobe acima da barra).

## Componentes compartilhados (`lib/core/widgets/`)

| Componente | Para quê |
|---|---|
| `LoadingView` | carregando, anunciado por leitor de tela |
| `EmptyStateView` | estado vazio: ícone, título, explicação, o próximo passo e, se houver, um atalho secundário no rodapé |
| `ErrorStateView` | erro com "Tentar novamente" |
| `showAppSnackBar` | aviso curto, substituindo o anterior |
| `PrimaryButton` | botão principal de formulário; desabilita e mostra progresso enquanto envia |
| `FormErrorBanner` | erro de formulário, anunciado assim que aparece |
| `PasswordField` | senha com mostrar/ocultar e erro do servidor |
| `AppNetworkImage` | imagem de rede com substituto enquanto carrega ou se falhar |

Do app inteiro: `AppBottomNavBar` e `PartyTabButton` (`lib/app/widgets/`).

## Padrões de tela

- Fundo `background`; na aba Perfil e na fila de análise, `backgroundMuted`
  com cartões em `surface`.
- Cartão: `surface`, raio 12 a 16, borda `divider` ou sombra leve. No tema
  escuro, sempre com borda. Em um cartão de **altura fixa** a borda do tema
  escuro é desenhada por cima (`foregroundDecoration`), para não tirar espaço
  do conteúdo (`listing_card.dart`).
- Função prevista e não construída: item visível, com "Em breve" no lugar da
  seta, sem responder ao toque.
- Botão que não pode agir fica desabilitado.
- Item selecionado: fundo `tint(primary)`, texto em `primary` e um visto. Em
  um filtro com ícone, o visto ocupa o lugar do ícone (`explore_page.dart`).
- Ação destrutiva: texto em `danger` e confirmação.
- Toda lista longa tem carregando, vazio e erro.

## Resposta ao toque

Uma mudança de estado é mostrada com uma transição curta (até 200 ms), e não
com um salto:

| Onde | O que anima |
|---|---|
| Favoritar e adicionar à festa (`listing_card.dart`) | o ícone troca com um efeito de escala |
| Aba ativa (`app_bottom_nav_bar.dart`) | o traço acima do ícone cresce; o botão central ganha um halo laranja |
| Seletor Cliente/Fornecedor do perfil | o fundo da opção escolhida |
| Troca de tema | todas as cores, juntas |

## Limites conhecidos

- Antes de o Flutter desenhar a primeira tela, a janela é pintada pelo
  sistema, que só conhece o tema dele. Quem escolheu no app um tema diferente
  do do aparelho vê a abertura na cor do sistema por um instante.
- No iOS a tela de abertura é branca fixa
  ([ios-build](../09-guides/ios-build.md)).
- As capturas do tema escuro foram conferidas em imagem, geradas pelos
  testes. O tema escuro não foi visto em um aparelho de verdade.
