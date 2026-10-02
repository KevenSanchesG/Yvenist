import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/client/favorites/presentation/controllers/favorites_controller.dart';
import 'package:yvenist/features/client/shared/listing_tile.dart';

/// Anúncios favoritados pela conta.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final items = favorites.items;

    final Widget body;
    if (!favorites.hasLoaded) {
      body = const LoadingView(label: 'Carregando favoritos');
    } else if (favorites.loadError != null && items.isEmpty) {
      body = ErrorStateView(
        message: favorites.loadError!,
        onRetry: favorites.load,
      );
    } else if (items.isEmpty) {
      body = EmptyStateView(
        icon: Icons.favorite_border,
        title: 'Você ainda não tem favoritos',
        message: 'Toque no coração de um anúncio para guardá-lo aqui.',
        actionLabel: 'Ver anúncios',
        onAction: () => Navigator.pop(context),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: favorites.load,
        child: ListView.separated(
          padding: context.withSystemBottomInset(const EdgeInsets.all(16)),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, index) => ListingTile(
            key: ValueKey(items[index].id),
            listing: items[index],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Favoritos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: 'Voltar',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: body,
    );
  }
}
