import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/form_widgets.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/auth/domain/auth_validators.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';
import 'package:yvenist/features/client/profile/presentation/widgets/profile_widgets.dart';

/// Segurança da conta: senha e exclusão da conta.
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Segurança')),
      body: ListView(
        padding: context.withSystemBottomInset(const EdgeInsets.all(20)),
        children: [
          const ProfileSectionTitle('Acesso'),
          ProfileActionTile(
            title: 'Alterar senha',
            subtitle: 'Encerra as sessões nos outros aparelhos',
            icon: Icons.lock_outline,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
          ),
          const ProfileActionTile(
            title: 'Autenticação em dois fatores',
            icon: Icons.phonelink_lock,
          ),
          const SizedBox(height: 12),
          const ProfileSectionTitle('Dispositivos'),
          const ProfileActionTile(
            title: 'Dispositivos conectados',
            icon: Icons.devices,
          ),
          const SizedBox(height: 12),
          const ProfileSectionTitle('Dados'),
          ProfileActionTile(
            title: 'Excluir conta',
            subtitle: 'Apaga a conta, as festas e os favoritos',
            icon: Icons.delete_forever,
            isDestructive: true,
            onTap: () => _confirmDeletion(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletion(BuildContext context) async {
    // Guardados antes: depois de voltar ao início esta tela não existe mais.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final tabs = context.read<AppTabController>();

    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted != true) return;

    // A conta não existe mais: volta ao início e avisa.
    tabs.goTo(AppTab.home);
    navigator.popUntil((route) => route.isFirst);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Sua conta foi excluída.')));
  }
}

/// Confirmação da exclusão: ação irreversível, exige a senha.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionController>().clearError();
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_formKey.currentState!.validate()) return;

    final deleted = await context.read<SessionController>().deleteAccount(
      password: _password.text,
    );
    if (deleted && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return AlertDialog(
      title: const Text('Excluir a conta?'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sua conta, suas festas e seus favoritos serão apagados. '
                'Isso não pode ser desfeito.',
              ),
              const SizedBox(height: 16),
              if (session.error != null) ...[
                FormErrorBanner(message: session.error!),
                const SizedBox(height: 12),
              ],
              PasswordField(
                controller: _password,
                label: 'Confirme com a sua senha',
                validator: validateCurrentPassword,
                onFieldSubmitted: (_) => _delete(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: session.isBusy
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: session.isBusy ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: context.colors.danger),
          child: Text(session.isBusy ? 'Excluindo...' : 'Excluir conta'),
        ),
      ],
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionController>().clearError();
    });
  }

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final messenger = ScaffoldMessenger.of(context);
    final changed = await context.read<SessionController>().changePassword(
      currentPassword: _current.text,
      newPassword: _newPassword.text,
    );
    if (!changed || !mounted) return;

    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Senha alterada.')));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Alterar senha')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (session.error != null) ...[
                  FormErrorBanner(message: session.error!),
                  const SizedBox(height: 16),
                ],
                PasswordField(
                  controller: _current,
                  label: 'Senha atual',
                  textInputAction: TextInputAction.next,
                  validator: validateCurrentPassword,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _newPassword,
                  label: 'Nova senha',
                  isNewPassword: true,
                  textInputAction: TextInputAction.next,
                  validator: validateNewPassword,
                  helperText: 'Pelo menos $passwordMinLength caracteres.',
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirmation,
                  label: 'Repita a nova senha',
                  isNewPassword: true,
                  validator: (value) =>
                      validatePasswordConfirmation(value, _newPassword.text),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Alterar senha',
                  isLoading: session.isBusy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
