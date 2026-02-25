import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

// CORREÇÃO AQUI: Import direto, pois estão na mesma pasta
import '../../../shared/ui/common_components.dart'; 

// Imports das Telas de Destino
import '../../../features/client/search/presentation/pages/search_page.dart';
import '../../../features/shared_features/notifications/presentation/pages/notifications_page.dart';
import '../../../features/client/favorites/presentation/pages/favorites_page.dart';

class CustomHeader extends StatefulWidget {
  const CustomHeader({super.key});
  @override
  State<CustomHeader> createState() => _CustomHeaderState();
}

class _CustomHeaderState extends State<CustomHeader> {
  final ScrollController _scrollController = ScrollController();
  int _activeIndex = 0;
  
  @override
  void initState() { super.initState(); _scrollController.addListener(_scrollListener); }
  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }
  
  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final double offset = _scrollController.offset;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    int newIndex;
    if (offset < maxScroll * 0.33) { newIndex = 0; } 
    else if (offset < maxScroll * 0.66) { newIndex = 1; } 
    else { newIndex = 2; }
    if (newIndex != _activeIndex) { setState(() { _activeIndex = newIndex; }); }
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: statusBarHeight + 16, bottom: AppSpacing.headerVerticalPadding),
      decoration: const BoxDecoration(
        color: AppColors.headerBackground,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.headerHorizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Navega para a tela de Pesquisa
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(color: AppColors.searchFieldBackground, borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(children: [const Icon(Icons.search, size: 24, color: AppColors.searchPlaceholder), const SizedBox(width: 10), Expanded(child: Text('O que vamos comemorar?', style: AppTypography.headerSearch.copyWith(fontSize: 14), overflow: TextOverflow.ellipsis))]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botão de Favoritos
                HeaderIconButton(icon: Icons.favorite_border, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesScreen()));
                }),
                const SizedBox(width: 12),
                // Botão de Notificações
                HeaderIconButton(icon: Icons.notifications_none, onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // --- CATEGORIAS ---
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.headerHorizontalPadding),
            child: const Row(
              children: [
                CategoryItem(label: 'Salões', icon: Icons.table_restaurant, isSelected: true),
                SizedBox(width: AppSpacing.categorySpacing),
                CategoryItem(label: 'Atrações', icon: Icons.music_note),
                SizedBox(width: AppSpacing.categorySpacing),
                CategoryItem(label: 'Brinquedos', icon: Icons.castle),
                SizedBox(width: AppSpacing.categorySpacing),
                CategoryItem(label: 'Serviços', icon: Icons.flatware),
                SizedBox(width: AppSpacing.categorySpacing),
                CategoryItem(label: 'Decorações', icon: Icons.local_florist),
                SizedBox(width: AppSpacing.categorySpacing),
                CategoryItem(label: 'Casamentos', icon: Icons.diamond),
                SizedBox(width: AppSpacing.categorySpacing),
                CategoryItem(label: '15 anos', icon: Icons.auto_awesome),
                SizedBox(width: AppSpacing.categorySpacing),
                CategoryItem(label: 'Beleza', icon: Icons.brush),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // --- INDICADOR ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDot(0), const SizedBox(width: 4), _buildDot(1), const SizedBox(width: 4), _buildDot(2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    bool isActive = index == _activeIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), width: isActive ? 6 : 4, height: isActive ? 6 : 4,
      decoration: BoxDecoration(color: isActive ? Colors.black : Colors.grey.withOpacity(0.5), shape: BoxShape.circle),
    );
  }
}