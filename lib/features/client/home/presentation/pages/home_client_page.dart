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
import '../../../../party_maker/presentation/pages/my_parties_page.dart';
import '../../../../party_maker/presentation/controllers/party_maker_controller.dart';
import '../../../explore/presentation/pages/explore_pages.dart';
import '../../../../party_maker/presentation/pages/party_builder_page.dart';
import '../../../../shared_features/chat/presentation/pages/chat_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// ✅ Forma correta de trocar aba de QUALQUER lugar:
  /// HomeScreen.changeTab(context, 2);
  static void changeTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    state?._setTab(index);
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _setTab(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

  // ATENÇÃO: _pages como getter para ter acesso ao state/métodos
  List<Widget> get _pages => [
        const _HomeContent(), // 0: Home

        // 1: Explore - volta para Home via troca de aba (sem Navigator)
        ExploreScreen(onBack: () => _setTab(0)),

        // 2: PartyMaker entrypoint (sem push/pop)
        Builder(
          builder: (context) {
            final controller = context.watch<PartyMakerController>();

            // ✅ REGRA CORRETA (entrypoint + sessão ativa)
            // 1) Se existe festa ativa -> Builder
            // 2) Se não existe nenhuma festa -> Builder (estado vazio / criação)
            // 3) Caso contrário -> Dashboard (MyParties)
            final hasActiveParty = controller.activePartyId != null;
            final hasAnyParty = controller.parties.isNotEmpty;

            if (hasActiveParty || !hasAnyParty) {
              return const PartyBuilderPage();
            }

            return const MyPartiesPage();
          },
        ),

        // 3: Chat - volta para Home via troca de aba (sem Navigator)
        ChatScreen(onBack: () => _setTab(0)),

        const ProfileScreen(), // 4: Perfil
      ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: CustomBottomNavBar(
          selectedIndex: _selectedIndex,
          onTabChange: _setTab, // ✅ único lugar que troca aba
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