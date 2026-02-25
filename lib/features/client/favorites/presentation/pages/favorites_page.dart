import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/state/global_app_state.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Meus Favoritos", style: AppTypography.sectionTitle),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: favoritesNotifier,
        builder: (context, favoriteItems, child) {
          if (favoriteItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("Você ainda não tem favoritos", style: AppTypography.sectionTitle.copyWith(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: favoriteItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = favoriteItems[index];
              return Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))]),
                child: ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['imageUrl'], width: 60, height: 60, fit: BoxFit.cover)),
                  title: Text(item['title'], style: AppTypography.cardTitle.copyWith(fontSize: 14)),
                  subtitle: Text(item['location'], style: AppTypography.cardLocation),
                  trailing: const Icon(Icons.favorite, color: AppColors.primary),
                ),
              );
            },
          );
        },
      ),
    );
  }
}