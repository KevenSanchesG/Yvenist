import 'package:flutter/material.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';

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

/// Nota no formato brasileiro: `4.8` -> `4,8`.
String formatRating(double rating) {
  return rating.toStringAsFixed(1).replaceAll('.', ',');
}
