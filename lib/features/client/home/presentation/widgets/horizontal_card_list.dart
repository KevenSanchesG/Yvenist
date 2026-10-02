import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/shared/listing_card.dart';

/// Lista horizontal de cards de anúncio.
class HorizontalCardList extends StatelessWidget {
  const HorizontalCardList({super.key, required this.listings});

  final List<Listing> listings;

  @override
  Widget build(BuildContext context) {
    // A altura acompanha o tamanho de fonte escolhido no sistema: com letras
    // maiores os cards crescem, em vez de cortar o texto.
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final height = ListingCard.imageHeight + 40 + 58 * textScale;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sectionHorizontalPadding,
          0,
          AppSpacing.sectionHorizontalPadding,
          // Espaço para a sombra dos cards.
          16,
        ),
        itemCount: listings.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.cardSpacing),
        itemBuilder: (_, index) => ListingCard(listing: listings[index]),
      ),
    );
  }
}
