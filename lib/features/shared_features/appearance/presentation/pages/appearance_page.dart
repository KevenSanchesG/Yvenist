import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/theme/theme_mode_controller.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/client/profile/presentation/widgets/profile_widgets.dart';

/// Aparência: tema claro, escuro ou o do aparelho.
///
/// A escolha vale na hora, sem botão de salvar: a própria tela é a prévia. É
/// uma preferência do aparelho, por isso a tela também é oferecida a quem não
/// entrou em uma conta.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  static const List<
    ({ThemeMode mode, IconData icon, String title, String subtitle})
  >
  _options = [
    (
      mode: ThemeMode.system,
      icon: Icons.brightness_auto_outlined,
      title: 'Padrão do aparelho',
      subtitle: 'Acompanha o tema claro ou escuro do sistema.',
    ),
    (
      mode: ThemeMode.light,
      icon: Icons.light_mode_outlined,
      title: 'Claro',
      subtitle: 'Fundo branco. Melhor em lugares bem iluminados.',
    ),
    (
      mode: ThemeMode.dark,
      icon: Icons.dark_mode_outlined,
      title: 'Escuro',
      subtitle: 'Fundo escuro. Cansa menos a vista com pouca luz.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeModeController>();
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Aparência')),
      body: ListView(
        padding: context.withSystemBottomInset(const EdgeInsets.all(20)),
        children: [
          const ProfileSectionTitle('Tema'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.divider),
            ),
            child: RadioGroup<ThemeMode>(
              groupValue: theme.mode,
              onChanged: (mode) {
                if (mode != null) theme.select(mode);
              },
              child: Column(
                children: [
                  for (final (index, option) in _options.indexed) ...[
                    if (index > 0) const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      value: option.mode,
                      title: Text(option.title),
                      subtitle: Text(option.subtitle),
                      secondary: ExcludeSemantics(child: Icon(option.icon)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'A escolha vale para este aparelho e continua valendo depois de '
            'fechar o app, com ou sem conta.',
            style: context.text.caption,
          ),
        ],
      ),
    );
  }
}
