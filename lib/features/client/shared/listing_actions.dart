import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/auth/presentation/auth_gate.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/favorites/presentation/controllers/favorites_controller.dart';
import 'package:yvenist/features/party_maker/presentation/add_to_party_flow.dart';

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

/// Começa o caminho do anúncio até dentro de uma festa.
///
/// Daqui em diante é o Party Maker que conduz: a escolha da festa, a
/// configuração do item pela categoria dele e a gravação. A vitrine só diz
/// qual anúncio a pessoa escolheu.
Future<void> addListingToParty(BuildContext context, Listing listing) async {
  final signedIn = await ensureSignedIn(
    context,
    reason: 'Entre para montar a sua festa.',
  );
  if (!signedIn || !context.mounted) return;

  await startAddToPartyFlow(
    context,
    listingId: listing.id,
    itemName: listing.title,
  );
}
