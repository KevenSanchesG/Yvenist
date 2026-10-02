import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Widgets compartilhados
import '../../../../../core/ui/layout/custom_header.dart';
import '../widgets/section_header.dart';
import '../widgets/horizontal_card_list.dart';
import '../widgets/content_card.dart';
import '../../../../../core/ui/navigation/custom_bottom_nav_bar.dart';

// Import das outras telas
import '../../../../../core/navigation/app_tab_controller.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../party_maker/presentation/pages/party_maker_entry_page.dart';
import '../../../explore/presentation/pages/explore_pages.dart';
import '../../../../shared_features/chat/presentation/pages/chat_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<AppTabController>();
    void goHome() => tabs.goTo(AppTab.home);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUi,
      child: Scaffold(
        body: IndexedStack(
          index: tabs.current.index,
          children: [
            const _HomeContent(),
            ExploreScreen(onBack: goHome),
            const PartyMakerEntryPage(),
            ChatScreen(onBack: goHome),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(
          selectedIndex: tabs.current.index,
          onTabChange: (index) => tabs.goTo(AppTab.values[index]),
        ),
      ),
    );
  }
}

// ... (O resto do arquivo, classe _HomeContent, continua igual)
class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const CustomHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // SEÇÃO 1: SALÕES
                  const SectionHeader(
                    title: 'Salões muito procurados na sua região',
                    subtitle: 'Descubra os melhores espaços para sua festa',
                  ),
                  const SizedBox(height: 16),
                  HorizontalCardList(
                    cards: List.generate(8, (index) {
                      return ContentCard(
                        title: 'Salão Glamour ${index + 1}',
                        price: '${1000 + (index * 100)}',
                        rating: 5.0,
                        reviews: 120 + index,
                        location: 'Campo Grande, RJ',
                        imageUrl:
                            'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=300&q=80',
                      );
                    }),
                  ),

                  const SizedBox(height: 32),

                  // SEÇÃO 2: ATRAÇÕES
                  const SectionHeader(
                    title: 'Atrações que estão em alta nas festas',
                    subtitle: 'Dê vida a sua festa com as melhores opções',
                  ),
                  const SizedBox(height: 16),
                  HorizontalCardList(
                    cards: List.generate(8, (index) {
                      return ContentCard(
                        title: 'Atração Festiva ${index + 1}',
                        price: '${800 + (index * 50)}',
                        rating: 4.8,
                        reviews: 85 + index,
                        location: 'Barra da Tijuca, RJ',
                        imageUrl:
                            'https://images.unsplash.com/photo-1523438885200-e635ba2c371e?auto=format&fit=crop&w=300&q=80',
                      );
                    }),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}