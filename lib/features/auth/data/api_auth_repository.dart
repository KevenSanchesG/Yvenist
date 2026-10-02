import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/core/storage/token_storage.dart';
import 'package:yvenist/features/auth/domain/entities/app_user.dart';
import 'package:yvenist/features/auth/domain/repositories/auth_repository.dart';

/// Autenticação pela API do Yvenist.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  @override
  Future<AppUser?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      final json = await _api.get('/users/me', authenticated: true) as Json;
      return userFromJson(json);
    } on UnauthorizedFailure {
      // A sessão guardada não vale mais; o cliente HTTP já apagou os tokens.
      return null;
    }
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) {
    return _startSession(
      '/auth/login',
      {'email': email.trim(), 'password': password},
    );
  }

  @override
  Future<AppUser> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _startSession('/auth/register', {
      'full_name': fullName.trim(),
      'email': email.trim(),
      'password': password,
      // A tela só chama o cadastro depois que a pessoa marca o aceite.
      'accept_terms': true,
    });
  }

  @override
  Future<void> signOut() async {
    final tokens = await _tokens.read();
    await _tokens.clear();
    if (tokens == null) return;
    try {
      await _api.post('/auth/logout', body: {'refresh_token': tokens.refreshToken});
    } on AppFailure {
      // Sem rede, a sessão local já foi encerrada; a do servidor expira sozinha.
    }
  }

  @override
  Future<AppUser> updateProfile({
    required String fullName,
    required String? phone,
    required DateTime? birthDate,
  }) async {
    final json = await _api.patch(
      '/users/me',
      authenticated: true,
      body: {
        'full_name': fullName.trim(),
        'phone': (phone == null || phone.trim().isEmpty) ? null : phone,
        'birth_date': birthDate == null ? null : _dateOnly(birthDate),
      },
    ) as Json;
    return userFromJson(json);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final json = await _api.post(
      '/users/me/password',
      authenticated: true,
      body: {'current_password': currentPassword, 'new_password': newPassword},
    ) as Json;
    // A troca invalida os tokens antigos; a resposta traz o novo par.
    await _tokens.write(AuthTokens.fromJson(json));
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    await _api.post(
      '/users/me/delete',
      authenticated: true,
      body: {'password': password},
    );
    await _tokens.clear();
  }

  Future<AppUser> _startSession(String path, Json body) async {
    final json = await _api.post(path, body: body) as Json;
    await _tokens.write(AuthTokens.fromJson(json['tokens'] as Json));
    return userFromJson(json['user'] as Json);
  }

  static String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static AppUser userFromJson(Json json) {
    final birthDate = json['birth_date'] as String?;
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      birthDate: birthDate == null ? null : DateTime.parse(birthDate),
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }
}
