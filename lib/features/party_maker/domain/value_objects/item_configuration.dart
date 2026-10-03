/// O que a pessoa informou ao configurar um item: a duração, o tema, as
/// observações. Cada categoria tem os seus campos
/// (`rules/item_configuration_spec.dart`); aqui ficam só os valores.
class ItemConfiguration {
  const ItemConfiguration._(this.values);

  factory ItemConfiguration(Map<String, Object> values) {
    return ItemConfiguration._(Map.unmodifiable(values));
  }

  static const ItemConfiguration empty = ItemConfiguration._({});

  /// A duração contratada, em horas: é a medida de quem cobra por hora.
  static const String durationKey = 'duration_hours';
  static const String notesKey = 'notes';

  /// O valor de cada campo preenchido: um inteiro ou um texto.
  final Map<String, Object> values;

  Object? operator [](String key) => values[key];

  bool get isEmpty => values.isEmpty;

  int? get durationHours {
    final value = values[durationKey];
    return value is int ? value : null;
  }

  @override
  bool operator ==(Object other) {
    if (other is! ItemConfiguration) return false;
    if (other.values.length != values.length) return false;
    for (final entry in values.entries) {
      if (other.values[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );

  @override
  String toString() => 'ItemConfiguration($values)';
}
