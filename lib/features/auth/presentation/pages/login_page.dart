import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';
import 'package:yvenist/core/widgets/form_widgets.dart';
import 'package:yvenist/features/auth/data/in_memory_auth_repository.dart';
import 'package:yvenist/features/auth/domain/auth_validators.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';
import 'package:yvenist/features/auth/presentation/pages/register_page.dart';

/// Entrar na conta. Fecha devolvendo `true` quando a pessoa fica autenticada.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.reason});

  /// Por que o login está sendo pedido (ex.: "para salvar favoritos").
  final String? reason;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Um erro deixado por uma tentativa anterior não deve aparecer de novo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionController>().clearError();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final signedIn = await context.read<SessionController>().signIn(
          email: _email.text,
          password: _password.text,
        );
    if (signedIn && mounted) Navigator.pop(context, true);
  }

  Future<void> _openRegister() async {
    final registered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
    if (registered == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isDemo = context.read<AppConfig>().isDemoMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fechar',
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ExcludeSemantics(
                    child: Icon(Icons.cake, size: 56, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.reason ?? 'Entre para planejar a sua festa.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (isDemo) ...[
                    const _DemoHint(),
                    const SizedBox(height: 16),
                  ],
                  if (session.error != null) ...[
                    FormErrorBanner(message: session.error!),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    validator: validateEmail,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _password,
                    label: 'Senha',
                    validator: validateCurrentPassword,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Entrar',
                    isLoading: session.isBusy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: session.isBusy ? null : _openRegister,
                    child: const Text('Não tem conta? Criar conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.headerBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Modo demonstração: os dados ficam só neste aparelho.\n'
        'Conta de teste: ${InMemoryAuthRepository.demoEmail} · '
        'senha ${InMemoryAuthRepository.demoPassword}',
        style: AppTypography.caption,
        textAlign: TextAlign.center,
      ),
    );
  }
}
