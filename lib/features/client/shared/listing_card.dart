import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/app_network_image.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/favorites/presentation/controllers/favorites_controller.dart';
import 'package:yvenist/features/client/shared/catalog_presentation.dart';
import 'package:yvenist/features/client/shared/listing_actions.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';

/// Descrição de um anúncio para leitores de tela, em uma frase só.
String listingSemanticLabel(Listing listing) {
  final price = formatBrl(listing.priceFromCents, hideZeroCents: true);
  final rating = listing.hasRatings
      ? 'Nota ${formatRating(listing.ratingAverage)} de 5, '
            '${listing.ratingCount} avaliações'
      : 'Ainda sem avaliações';
  return '${listing.title}. A partir de $price. $rating. '
      '${listing.locationLabel}.';
}

/// Card vertical de um anúncio, usado nas listas horizontais e em grades.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, this.width = cardWidth});

  static const double cardWidth = 165;
  static const double imageHeight = 150;

  final Listing listing;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      // No tema escuro a sombra não se vê: a borda delimita o card. Desenhada
      // por cima, e não como borda do fundo, para não tirar espaço do
      // conteúdo: o card tem altura fixa nas listas horizontais.
      foregroundDecoration: colors.isDark
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.divider),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              AppNetworkImage(
                url: listing.coverImageUrl,
                width: width,
                height: imageHeight,
              ),
              // Limitado à largura do card: com letras grandes o selo encolhe
              // para caber, em vez de ter o preço cortado pela borda.
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PriceBadge(listing: listing),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: ListingActionButtons(listing: listing),
              ),
            ],
          ),
          Semantics(
            label: listingSemanticLabel(listing),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: context.text.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    RatingRow(listing: listing),
                    const SizedBox(height: 4),
                    LocationRow(listing: listing),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selo "A partir de R$ ...", no laranja da marca.
class PriceBadge extends StatelessWidget {
  const PriceBadge({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'A partir de ${formatBrl(listing.priceFromCents, hideZeroCents: true)}',
        style: context.text.cardPrice,
      ),
    );
  }
}

class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    if (!listing.hasRatings) {
      return Text('Novo', style: text.cardRatingCount);
    }

    return Row(
      children: [
        Icon(Icons.star, size: 14, color: context.colors.primary),
        const SizedBox(width: 4),
        Text(formatRating(listing.ratingAverage), style: text.cardRatingScore),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '(${listing.ratingCount})',
            style: text.cardRatingCount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class LocationRow extends StatelessWidget {
  const LocationRow({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 14,
          color: context.colors.primary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            listing.locationLabel,
            style: context.text.cardLocation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Botões "adicionar à festa" e "favoritar" de um anúncio.
///
/// Cada botão ocupa 48x48 de área de toque (o círculo desenhado é menor) e tem
/// rótulo para leitores de tela. Usam `select` para reconstruir só o botão do
/// anúncio que mudou, e não todos os cards da tela.
class ListingActionButtons extends StatelessWidget {
  const ListingActionButtons({
    super.key,
    required this.listing,
    this.direction = Axis.horizontal,
  });

  final Listing listing;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.select<FavoritesController, bool>(
      (favorites) => favorites.isFavorite(listing.id),
    );
    final isInParty = context.select<PartyMakerController, bool>(
      (parties) => parties.isInAnyParty(listing.id),
    );

    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundAction(
          icon: isInParty ? Icons.check : Icons.add,
          highlighted: isInParty,
          tooltip: isInParty
              ? '${listing.title} já está em uma festa. Adicionar a outra'
              : 'Adicionar ${listing.title} a uma festa',
          onPressed: () => addListingToParty(context, listing),
        ),
        _RoundAction(
          icon: isFavorite ? Icons.favorite : Icons.favorite_border,
          highlighted: isFavorite,
          tooltip: isFavorite
              ? 'Remover ${listing.title} dos favoritos'
              : 'Favoritar ${listing.title}',
          onPressed: () => toggleFavorite(context, listing),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.highlighted,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool highlighted;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      isSelected: highlighted,
      iconSize: 20,
      // Marcar e desmarcar troca o ícone com uma transição curta, em vez de
      // um salto: é a resposta visual ao toque.
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(icon, key: ValueKey(icon)),
      ),
      style: IconButton.styleFrom(
        backgroundColor: highlighted ? colors.primary : colors.raisedSurface,
        foregroundColor: highlighted ? colors.onPrimary : colors.primary,
        elevation: 2,
        shadowColor: colors.shadow,
        fixedSize: const Size(34, 34),
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        // Mantém 48x48 de área de toque em volta do círculo de 34.
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
