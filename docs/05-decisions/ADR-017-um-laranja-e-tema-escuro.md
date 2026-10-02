---
title: "ADR-017: Um laranja por tema, tema escuro e a escolha em Aparência"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-017: Um laranja por tema, tema escuro e a escolha em Aparência

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** os donos do
projeto (o tom da marca, a existência do tema escuro e onde fica a escolha);
a execução, com as melhorias de desenho que eles deixaram em aberto, é
técnica. Substitui o [ADR-008](ADR-008-acessibilidade-e-cores.md).

## Contexto

O [ADR-008](ADR-008-acessibilidade-e-cores.md) convivia com dois laranjas:
`#FF6600`, a cor da marca, com contraste de 2,94:1 sobre branco, só em ícones
e áreas grandes; e `#C2410C` (5,18:1) em tudo o que era texto, link e botão.
O tom da marca ficou como pendência dos donos. O app tinha um tema só, claro.

Em 2 de outubro de 2026 os donos responderam:

- o tom principal é **`#C2410C`**;
- o app deve ter uma **versão em tema escuro**, e é a pessoa que escolhe, nas
  configurações do perfil;
- as demais melhorias de desenho, seguindo as normas de interação
  humano-computador e o uso das cores, ficam a critério técnico.

## Problema

Como ter dois temas sem que cada tela precise saber em qual está, e sem perder
o que o ADR-008 garantia (contraste conferido por teste)?

## Decisão

**Um laranja por tema.** `#C2410C` no claro e, no escuro, o mesmo matiz mais
claro, `#FB8656` (7,60:1 sobre o fundo escuro). `#C2410C` sobre o fundo escuro
teria 3,57:1: não serve como texto. `#FF6600` saiu do app.

**As cores viram uma paleta por tema.** `AppPalette`
(`lib/core/theme/app_palette.dart`) tem os mesmos papéis nos dois temas
(`primary`, `surface`, `textSecondary`, `danger`…) com valores diferentes, e
entra no tema como extensão. As telas leem `context.colors` e `context.text`
(`lib/core/theme/app_theme.dart`); nenhuma escreve uma cor. Só o que é igual
nos dois temas continua constante, em `AppColors` (a marca, os degradês com
texto branco, a película sobre foto).

**Tema escuro desenhado, e não invertido** (os valores estão em
[design-system](../04-ux/design-system.md)):

- fundo cinza muito escuro (`#121416`), e não preto: texto claro sobre preto
  puro tem contraste demais e cansa;
- profundidade por superfícies mais claras que o fundo, com borda, porque a
  sombra não se vê no escuro;
- cores de destaque e de estado mais claras que as do tema claro, para manter
  o contraste;
- o destaque de item selecionado mais forte (16% da cor, contra 8% no claro),
  porque um tom suave some sobre fundo escuro.

**A escolha fica em Perfil → Configurações e suporte → Aparência**, com três
opções: "Padrão do aparelho" (o valor inicial), "Claro" e "Escuro"
(`appearance_page.dart`). Vale na hora, sem botão de salvar. Quem não entrou
em uma conta chega à mesma tela por um atalho na aba Perfil.

**A escolha é do aparelho, e não da conta.** `ThemeModeController` a guarda
pelo `flutter_secure_storage`, na chave `yvenist.theme_mode`
(`lib/core/storage/theme_preference_storage.dart`), e ela é lida antes da
primeira tela (`lib/main.dart`). Não vai para o servidor.

**O que continua valendo do ADR-008:** o contraste é conferido por teste sobre
os pares de cores, agora nos dois temas (`test/core/theme_contrast_test.dart`);
superfícies neutras, sem a tinta que o Material deriva da marca; área de toque
de 48×48, rótulo em todo controle, nenhuma tela estourando com a fonte em
200%; nenhum texto abaixo de 11.

## Consequências

- Um laranja só resolve o que o ADR-008 deixava em aberto: ícones, barra de
  progresso e indicadores passam de 2,94:1 para 5,18:1.
- A marca fica mais escura e menos vibrante que o `#FF6600` do protótipo. Foi
  a escolha dos donos.
- **Toda tela precisa funcionar nos dois temas.** Uma cor escrita à mão quebra
  um deles: `test/core/theme_usage_test.dart` falha se aparecer uma fora de
  `lib/core/theme/`. Os fluxos principais rodam de novo no tema escuro em
  `test/app/accessibility_test.dart`.
- A paleta tem duas restrições, que quem cria uma tela precisa conhecer:
  `textTertiary` não vai sobre `surfaceMuted` (4,35:1 no tema claro), e o
  destaque em laranja (`tint(primary)`) só vai sobre `background` e `surface`
  (sobre os fundos apagados o texto laranja fica abaixo de 4,5:1).
- A escolha de tema é o primeiro dado que o app guarda no aparelho além da
  sessão ([personal-data](../01-architecture/personal-data.md)).
- Antes de o Flutter desenhar, quem pinta a janela é o sistema, que só conhece
  o tema dele: quem escolheu um tema diferente do do aparelho vê a abertura na
  cor do sistema por um instante. No iOS a tela de abertura é branca fixa
  ([ios-build](../09-guides/ios-build.md)).
- As capturas de `docs/screenshots/` passam a existir nos dois temas para as
  telas principais.

## Alternativas consideradas

- **Manter os dois laranjas**: era a saída enquanto o tom não estava decidido.
  Com a decisão, só sobra a complexidade.
- **Usar `#C2410C` também no tema escuro**: um laranja só no app inteiro, mas
  com 3,57:1 sobre o fundo escuro ele não passa como texto nem como rótulo da
  aba ativa.
- **Guardar a escolha na conta, no servidor**: seguiria a pessoa entre
  aparelhos, mas não valeria para visitantes, exigiria rota e migração, e o
  tema certo depende do aparelho e do ambiente, não da pessoa.
- **`shared_preferences` para guardar a escolha**: é o pacote usual para
  preferências. Seria mais uma dependência com código nativo para guardar um
  valor; o `flutter_secure_storage` já está no app.
- **Só seguir o tema do aparelho, sem escolha**: mais simples, mas os donos
  pediram que a pessoa escolha.
- **Inverter as cores do tema claro**: fundo preto e os mesmos destaques. O
  laranja escuro não tem contraste, as sombras somem e os cartões se confundem
  com o fundo.
- **Deixar o Material derivar o esquema escuro do laranja**
  (`ColorScheme.fromSeed`): as superfícies saem tingidas de marrom, o mesmo
  problema que o ADR-008 corrigiu no tema claro.
