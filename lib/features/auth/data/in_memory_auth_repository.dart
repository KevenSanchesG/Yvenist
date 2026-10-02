import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/auth/domain/auth_validators.dart';
import 'package:yvenist/features/auth/domain/entities/app_user.dart';
import 'package:yvenist/features/auth/domain/repositories/auth_repository.dart';

/// Contas guardadas na memória: modo demonstração e testes.
///
/// No modo demonstração o app já abre com a conta [demoUser] autenticada, como
/// no protótipo original, que não tinha login. Sair da conta leva à tela de
/// entrada, onde [demoEmail] e [demoPassword] entram de novo.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({bool startSignedIn = true}) {
    _accounts[demoEmail] = _Account(demoUser, demoPassword);
    if (startSignedIn) _currentEmail = demoEmail;
  }

  static const String demoEmail = 'demo@yvenist.app';
  static const String demoPassword = 'demonstracao';
  static const AppUser demoUser = AppUser(
    id: 'demo-user',
    email: demoEmail,
    fullName: 'Conta Demonstração',
  );

  final Map<String, _Account> _accounts = {};
  String? _currentEmail;
  int _sequence = 0;

  /// Id da conta autenticada, para os outros repositórios em memória
  /// separarem os dados por conta.
  String? get currentUserId => _current?.user.id;

  @override
  Future<AppUser?> restoreSession() async => _current?.user;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final account = _accounts[_normalize(email)];
    if (account == null || account.password != password) {
      throw const UnauthorizedFailure(
        'E-mail ou senha inválidos.',
        'invalid_credentials',
      );
    }
    _currentEmail = account.user.email;
    return account.user;
  }

  @override
  Future<AppUser> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalized = _normalize(email);
    final error =
        validateEmail(normalized) ??
        validateNewPassword(password) ??
        validateFullName(fullName);
    if (error != null) throw ValidationFailure(error);
    if (_accounts.containsKey(normalized)) {
      throw const ConflictFailure(
        'Já existe uma conta com este e-mail.',
        'email_already_registered',
      );
    }

    final user = AppUser(
      id: 'user-${++_sequence}',
      email: normalized,
      fullName: fullName.trim(),
    );
    _accounts[normalized] = _Account(user, password);
    _currentEmail = normalized;
    return user;
  }

  @override
  Future<void> signOut() async => _currentEmail = null;

  @override
  Future<AppUser> updateProfile({
    required String fullName,
    required String? phone,
    required DateTime? birthDate,
  }) async {
    final account = _requireCurrent();
    final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    final updated = account.user.copyWith(
      fullName: fullName.trim(),
      phone: () => digits.isEmpty ? null : digits,
      birthDate: () => birthDate,
    );
    _accounts[updated.email] = _Account(updated, account.password);
    return updated;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final account = _requireCurrent();
    if (account.password != currentPassword) {
      throw const ValidationFailure(
        'Senha atual incorreta.',
        code: 'wrong_password',
      );
    }
    _accounts[account.user.email] = _Account(account.user, newPassword);
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final account = _requireCurrent();
    if (account.password != password) {
      throw const ValidationFailure('Senha incorreta.', code: 'wrong_password');
    }
    _accounts.remove(account.user.email);
    _currentEmail = null;

    // A conta de teste anunciada na tela de entrada continua existindo, mas
    // volta zerada: com outro id, não enxerga as festas e os favoritos da
    // conta que acabou de ser apagada.
    if (account.user.email == demoEmail) {
      _accounts[demoEmail] = _Account(
        AppUser(
          id: 'demo-user-${++_sequence}',
          email: demoEmail,
          fullName: demoUser.fullName,
        ),
        demoPassword,
      );
    }
  }

  _Account? get _current => _accounts[_currentEmail];

  _Account _requireCurrent() {
    final account = _current;
    if (account == null) throw const UnauthorizedFailure();
    return account;
  }

  static String _normalize(String email) => email.trim().toLowerCase();
}

class _Account {
  const _Account(this.user, this.password);

  final AppUser user;
  final String password;
}
