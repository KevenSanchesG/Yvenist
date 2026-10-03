import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_item_catalog.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/pricing.dart';

/// A ponte entre o catálogo e o Party Maker.
///
/// O Party Maker não importa nada do catálogo: é aqui, do lado de quem conhece
/// os dois, que um anúncio vira o que a festa entende.
class ListingPartyItemCatalog implements PartyItemCatalog {
  ListingPartyItemCatalog(this._catalog);

  final CatalogRepository _catalog;

  @override
  Future<PartyItemDraft> draftFor(String listingId) async {
    final detail = await _catalog.getListing(listingId);
    final listing = detail.listing;

    return listing.toPartyItemDraft(
      capacity: detail.capacity,
      ownServices: [
        for (final offer in detail.offers)
          PartyItemDraft(
            externalRef: ExternalRef.offer(offer.id),
            category: PartyItemCategory.fromSlug(offer.categorySlug),
            name: offer.name,
            description: offer.description,
            pricing: Pricing(
              model: offer.pricingModel,
              amount: _money(offer.priceCents, listing.currency),
              minimum: _money(offer.minimumPriceCents, listing.currency),
              currency: listing.currency,
            ),
            // Um serviço não tem foto: fica a do anúncio a que pertence.
            imageUrl: listing.coverImageUrl,
            isRequired: offer.isRequired,
          ),
      ],
      partners: [
        for (final partner in detail.partners) partner.toPartyItemDraft(),
      ],
    );
  }

  @override
  Future<List<EventTypeOption>> eventTypes() async {
    return [
      for (final type in await _catalog.eventTypes())
        EventTypeOption(slug: type.slug, name: type.name),
    ];
  }
}

extension ListingToPartyItem on Listing {
  /// O anúncio no formato que o Party Maker entende.
  PartyItemDraft toPartyItemDraft({
    int? capacity,
    List<PartyItemDraft> ownServices = const [],
    List<PartyItemDraft> partners = const [],
  }) {
    return PartyItemDraft(
      externalRef: ExternalRef.listing(id),
      category: PartyItemCategory.fromSlug(categorySlug),
      name: title,
      pricing: Pricing(
        model: pricingModel,
        amount: _money(priceFromCents, currency),
        minimum: _money(minimumPriceCents, currency),
        currency: currency,
      ),
      imageUrl: coverImageUrl,
      capacity: capacity,
      ownServices: ownServices,
      partners: partners,
    );
  }
}

Money? _money(int? cents, String currency) {
  return cents == null ? null : Money.fromCents(cents, currency: currency);
}
