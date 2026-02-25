import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/state/global_app_state.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

import '../../../../party_maker/domain/enums/party_item_category.dart';
import '../../../../party_maker/presentation/controllers/party_maker_controller.dart';

class ContentCard extends StatefulWidget {
  final String title;
  final String price;
  final double rating;
  final int reviews;
  final String location;
  final String imageUrl;

  const ContentCard({
    super.key,
    required this.title,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.location,
    required this.imageUrl,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  void _toggleFavorite() {
    final currentList = List<Map<String, dynamic>>.from(
      favoritesNotifier.value,
    );
    final exists = currentList.any((item) => item['title'] == widget.title);

    if (exists) {
      currentList.removeWhere((item) => item['title'] == widget.title);
    } else {
      currentList.add({
        'title': widget.title,
        'price': widget.price,
        'imageUrl': widget.imageUrl,
        'location': widget.location,
      });
    }

    favoritesNotifier.value = currentList;
  }

  Future<void> _toggleParty() async {
    const ownerId = 'user_1';

    final controller = context.read<PartyMakerController>();
    final externalId = widget.title; // MVP: title como externalId

    // Guard: se a party ativa estiver locked, não deixa mexer
    if (controller.isActivePartyLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Essa festa já foi bloqueada para orçamento."),
        ),
      );
      return;
    }

    // Se já está na party -> remover
    final partyItemId = controller.findPartyItemIdByExternalId(externalId);

    if (partyItemId != null) {
      final ok = await controller.removeItemFromActiveParty(partyItemId);

      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(controller.error ?? 'Erro ao remover item')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item removido da Festa atual')),
      );
      return;
    }

    // Se NÃO está na party -> adicionar
    final ok = await controller.addCardToActiveParty(
      ownerId: ownerId,
      cardTitle: widget.title,
      cardPrice: widget.price,
      externalId: externalId,
      category: PartyItemCategory.other,
      imagePath: widget.imageUrl, // cache da imagem
    );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.error ?? 'Erro ao adicionar item')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item adicionado na Festa atual')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 165,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Image.network(
                  widget.imageUrl,
                  width: 167,
                  height: 161,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 167,
                    height: 161,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'A partir de R\$ ${widget.price}',
                    style: AppTypography.cardPrice.copyWith(fontSize: 8),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    // ============================================================
                    // Favoritos (mantém do jeito que já estava)
                    // ============================================================
                    ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: favoritesNotifier,
                      builder: (context, favoriteList, child) {
                        final isFavorite = favoriteList.any(
                          (item) => item['title'] == widget.title,
                        );

                        return GestureDetector(
                          onTap: _toggleFavorite,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!isFavorite)
                                Icon(
                                  Icons.favorite,
                                  size: 26,
                                  color: Colors.black.withOpacity(0.3),
                                ),
                              Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                size: 26,
                                color: isFavorite ? AppColors.primary : Colors.white,
                                shadows: isFavorite
                                    ? []
                                    : const [
                                        Shadow(color: Colors.black26, blurRadius: 2),
                                      ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 8),

                    // ============================================================
                    // Party real (Domain)
                    // ============================================================
                    Consumer<PartyMakerController>(
                      builder: (context, controller, _) {
                        final isInParty = controller.isExternalItemInActiveParty(
                          widget.title,
                        );

                        return GestureDetector(
                          onTap: () => _toggleParty(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isInParty ? AppColors.primary : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isInParty ? Icons.check : Icons.add,
                              size: 18,
                              color: isInParty ? Colors.white : AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: AppTypography.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (index) => const Icon(
                        Icons.star,
                        size: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.rating.toStringAsFixed(1),
                      style: AppTypography.cardRatingScore,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '(${widget.reviews})',
                      style: AppTypography.cardRatingCount,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.location,
                        style: AppTypography.cardLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
