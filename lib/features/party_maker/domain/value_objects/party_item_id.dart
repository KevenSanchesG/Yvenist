class PartyItemId {
  final String value;
  const PartyItemId(this.value);

  @override
  bool operator ==(Object other) =>
      other is PartyItemId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PartyItemId($value)';
}
