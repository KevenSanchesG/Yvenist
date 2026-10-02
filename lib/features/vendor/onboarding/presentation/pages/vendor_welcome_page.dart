import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/widgets/app_network_image.dart';
import 'package:yvenist/features/vendor/onboarding/presentation/pages/ad_category_selection_page.dart';

/// Convite para anunciar: explica as vantagens e leva à escolha do que
/// anunciar.
class VendorWelcomePage extends StatelessWidget {
  const VendorWelcomePage({super.key});

  static const String _backgroundUrl =
      'https://images.unsplash.com/photo-1519167758481-83f550bb49b3'
      '?auto=format&fit=crop&w=800&q=80';

  static const List<({IconData icon, String text})> _benefits = [
    (icon: Icons.check_circle, text: 'Anunciar é gratuito'),
    (icon: Icons.check_circle, text: 'Você define suas regras e preços'),
    (icon: Icons.shield, text: 'Cada anúncio passa por análise'),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      // Fundo escuro mesmo que a foto não carregue: o texto branco continua
      // legível.
      backgroundColor: AppColors.vendor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppNetworkImage(
            url: _backgroundUrl,
            width: size.width,
            height: size.height,
          ),
          const ColoredBox(color: Color(0xB3000000)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Transforme seu espaço em renda extra',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'É fácil começar. Hoje você já pode anunciar o seu salão; '
                    'brinquedos, buffet e decoração chegam em seguida.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  for (final benefit in _benefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              benefit.icon,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              benefit.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdCategorySelectionPage(),
                        ),
                      ),
                      child: const Text('Começar meu anúncio'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
