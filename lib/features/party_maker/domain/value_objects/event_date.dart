/// O dia e a hora da festa.
///
/// Só guarda o valor. Que a data precisa ser no futuro é uma regra da festa
/// (`Party.updateEventDetails`), e não deste objeto: uma festa antiga, cuja
/// data já passou, tem de continuar podendo ser aberta.
class EventDate {
  const EventDate(this.value);

  final DateTime value;

  @override
  bool operator ==(Object other) =>
      other is EventDate && other.value.isAtSameMomentAs(value);

  @override
  int get hashCode => value.millisecondsSinceEpoch.hashCode;

  @override
  String toString() => 'EventDate($value)';
}
