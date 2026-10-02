import 'package:yvenist/features/auth/domain/entities/app_user.dart';

/// Contrato de autenticação e dados da conta.
///
/// As implementações lançam `AppFailure` com mensagem pronta para a tela.
abstract interface class AuthRepository {
  /// Recupera a sessão guardada no aparelho. `null` se não houver sessão ou se
  /// ela não for mais válida. Lança se não for possível verificar (sem rede).
  Future<AppUser?> restoreSession();

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  /// Encerra a sessão neste aparelho. Não falha: sair sempre funciona.
  Future<void> signOut();

  Future<AppUser> updateProfile({
    required String fullName,
    required String? phone,
    required DateTime? birthDate,
  });

  /// Troca a senha. As sessões de outros aparelhos são encerradas.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Apaga a conta e os dados associados, mediante confirmação da senha.
  Future<void> deleteAccount({required String password});
}
