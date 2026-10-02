import 'package:flutter/foundation.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/auth/domain/entities/app_user.dart';
import 'package:yvenist/features/auth/domain/repositories/auth_repository.dart';

enum SessionStatus {
  /// Ainda verificando se há sessão guardada no aparelho.
  restoring,
  signedOut,
  signedIn,

  /// Não foi possível verificar a sessão (sem rede). O app segue como
  /// visitante e oferece tentar de novo.
  restoreFailed,
}

/// Sessão do usuário para as telas: quem está logado e as operações de conta.
class SessionController extends ChangeNotifier {
  SessionController(this._repository);

  final AuthRepository _repository;

  SessionStatus _status = SessionStatus.restoring;
  AppUser? _user;
  bool _isBusy = false;
  AppFailure? _failure;
  bool _disposed = false;

  SessionStatus get status => _status;
  AppUser? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isBusy => _isBusy;

  /// Falha da última operação, para a tela exibir.
  AppFailure? get failure => _failure;
  String? get error => _failure?.message;

  /// Recupera a sessão guardada. Chamado uma vez, ao abrir o app.
  Future<void> restore() async {
    _status = SessionStatus.restoring;
    _notify();
    try {
      final user = await _repository.restoreSession();
      _setUser(user);
    } catch (_) {
      _user = null;
      _status = SessionStatus.restoreFailed;
      _notify();
    }
  }

  Future<bool> signIn({required String email, required String password}) {
    return _run(() async {
      _setUser(await _repository.signIn(email: email, password: password));
    });
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _run(() async {
      _setUser(
        await _repository.signUp(
          fullName: fullName,
          email: email,
          password: password,
        ),
      );
    });
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _setUser(null);
  }

  Future<bool> updateProfile({
    required String fullName,
    required String? phone,
    required DateTime? birthDate,
  }) {
    return _run(() async {
      _setUser(
        await _repository.updateProfile(
          fullName: fullName,
          phone: phone,
          birthDate: birthDate,
        ),
      );
    });
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _run(
      () => _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
  }

  Future<bool> deleteAccount({required String password}) {
    return _run(() async {
      await _repository.deleteAccount(password: password);
      _setUser(null);
    });
  }

  /// O servidor encerrou a sessão (expirou ou foi revogada em outro aparelho).
  void handleSessionExpired() {
    if (_user == null) return;
    _setUser(null);
  }

  void clearError() {
    if (_failure == null) return;
    _failure = null;
    _notify();
  }

  // ------------------------------------------------------------------

  Future<bool> _run(Future<void> Function() action) async {
    _failure = null;
    _isBusy = true;
    _notify();
    try {
      await action();
      return true;
    } catch (error) {
      _failure = error is AppFailure ? error : const UnexpectedFailure();
      return false;
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  void _setUser(AppUser? user) {
    _user = user;
    _status = user == null ? SessionStatus.signedOut : SessionStatus.signedIn;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
