class PartyId {
  final String value;
  const PartyId(this.value);

  @override
  bool operator ==(Object other) => other is PartyId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PartyId($value)';
}
