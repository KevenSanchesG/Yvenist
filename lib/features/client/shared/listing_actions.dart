import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/auth/presentation/auth_gate.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/favorites/presentation/controllers/favorites_controller.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/presentation/widgets/select_party_bottom_sheet.dart';

/// O que se pode fazer com um anúncio a partir de um card. Ficam aqui para a
/// vitrine, a busca e os favoritos se comportarem da mesma forma.

/// Favorita ou desfavorita, pedindo login antes se for um visitante.
Future<void> toggleFavorite(BuildContext context, Listing listing) async {
  final signedIn = await ensureSignedIn(
    context,
    reason: 'Entre para salvar seus favoritos.',
  );
  if (!signedIn || !context.mounted) return;

  final favorites = context.read<FavoritesController>();
  final confirmed = await favorites.toggle(listing);
  if (!confirmed && favorites.error != null && context.mounted) {
    showAppSnackBar(context, favorites.error!);
  }
}

/// Abre a escolha da festa que vai receber o anúncio.
Future<void> addListingToParty(BuildContext context, Listing listing) async {
  final signedIn = await ensureSignedIn(
    context,
    reason: 'Entre para montar a sua festa.',
  );
  if (!signedIn || !context.mounted) return;

  await showAddToPartySheet(context, listing.toPartyItemDraft());
}

extension ListingToPartyItem on Listing {
  /// Traduz o anúncio para o formato que o Party Maker entende.
  PartyItemDraft toPartyItemDraft() {
    return PartyItemDraft(
      externalRef: ExternalRef.listing(id),
      category: PartyItemCategory.fromSlug(categorySlug),
      name: title,
      unitPrice: Money.fromCents(priceFromCents, currency: currency),
      imageUrl: coverImageUrl,
    );
  }
}
