/// A conta autenticada.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.birthDate,
    this.isAdmin = false,
  });

  final String id;
  final String email;
  final String fullName;

  /// Só dígitos, com DDD (ex.: `21999998888`).
  final String? phone;
  final DateTime? birthDate;
  final bool isAdmin;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  /// Até duas letras para o avatar: primeira do nome e primeira do sobrenome.
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  AppUser copyWith({
    String? fullName,
    String? Function()? phone,
    DateTime? Function()? birthDate,
  }) {
    return AppUser(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone != null ? phone() : this.phone,
      birthDate: birthDate != null ? birthDate() : this.birthDate,
      isAdmin: isAdmin,
    );
  }
}
