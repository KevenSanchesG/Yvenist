import 'package:flutter/material.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';

/// Como os conceitos do catálogo aparecem na tela: ícones e rótulos.

const Map<String, IconData> _categoryIcons = {
  'venue': Icons.table_restaurant,
  'attraction': Icons.music_note,
  'kids': Icons.castle,
  'buffet': Icons.flatware,
  'decoration': Icons.local_florist,
  'beauty': Icons.brush,
  'dj': Icons.headphones,
  'staff': Icons.groups,
  'security': Icons.shield_outlined,
};

const Map<String, IconData> _eventTypeIcons = {
  'wedding': Icons.diamond,
  'debutante': Icons.auto_awesome,
  'kids_party': Icons.child_care,
  'corporate': Icons.business_center,
  'barbecue': Icons.outdoor_grill,
  'graduation': Icons.school,
};

/// Comodidades que um anúncio pode declarar: chave enviada à API, rótulo e
/// ícone. A API só valida a chave; o nome que a pessoa lê está aqui.
const List<({String slug, String label, IconData icon})> amenityOptions = [
  (slug: 'kitchen', label: 'Cozinha equipada', icon: Icons.kitchen),
  (slug: 'air_conditioning', label: 'Ar-condicionado', icon: Icons.ac_unit),
  (slug: 'parking', label: 'Estacionamento', icon: Icons.local_parking),
  (slug: 'kids_area', label: 'Área kids', icon: Icons.child_care),
  (slug: 'wifi', label: 'Wi-Fi', icon: Icons.wifi),
  (slug: 'accessibility', label: 'Acessibilidade', icon: Icons.accessible),
];

/// Rótulo de uma comodidade; uma chave que o app ainda não conhece aparece
/// como veio.
String amenityLabel(String slug) {
  for (final option in amenityOptions) {
    if (option.slug == slug) return option.label;
  }
  return slug;
}

extension CancellationPolicyPresentation on CancellationPolicy {
  String get label => switch (this) {
    CancellationPolicy.flexible => 'Flexível',
    CancellationPolicy.moderate => 'Moderada',
  };

  String get summary => switch (this) {
    CancellationPolicy.flexible => 'Reembolso total até 48h antes.',
    CancellationPolicy.moderate => 'Reembolso de 50% até 7 dias antes.',
  };
}

/// Ícone de uma categoria; chaves desconhecidas (uma categoria nova criada no
/// servidor) recebem um ícone genérico em vez de quebrar a tela.
IconData iconForCategory(String iconKey) {
  return _categoryIcons[iconKey] ?? Icons.category_outlined;
}

IconData iconForEventType(String slug) {
  return _eventTypeIcons[slug] ?? Icons.celebration;
}

extension ListingSortPresentation on ListingSort {
  String get label => switch (this) {
    ListingSort.popular => 'Mais procurados',
    ListingSort.priceAsc => 'Menor preço',
    ListingSort.priceDesc => 'Maior preço',
    ListingSort.recent => 'Mais recentes',
  };
}

extension ListingPricePresentation on Listing {
  /// O preço como aparece em um card: "A partir de R$ 1.700", "R$ 55 por
  /// pessoa", "Sob consulta".
  ///
  /// O valor fixo é o preço inicial informado pelo fornecedor, por isso o "a
  /// partir de"; os outros já dizem a que se referem.
  String get priceLabel {
    final price = describePricing(pricingModel, priceFromCents);
    return pricingModel == PricingModel.fixed ? 'A partir de $price' : price;
  }
}

/// Nota no formato brasileiro: `4.8` -> `4,8`.
String formatRating(double rating) {
  return rating.toStringAsFixed(1).replaceAll('.', ',');
}
