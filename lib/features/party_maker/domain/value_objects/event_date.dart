class EventDate {
  final DateTime value;

  EventDate(this.value) {
    // MVP: só armazenar. Se quiser proibir passado no futuro:
    // if (value.isBefore(DateTime.now())) { ... }
  }

  @override
  bool operator ==(Object other) => other is EventDate && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'EventDate($value)';
}
