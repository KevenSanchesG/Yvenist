import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/form_widgets.dart';
import 'package:yvenist/features/auth/domain/auth_validators.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';
import 'package:yvenist/features/shared_features/legal/presentation/pages/legal_page.dart';

/// Criar conta. Fecha devolvendo `true` quando a conta é criada.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  /// Nomes, na API, dos campos que esta tela mostra.
  static const List<String> _formFields = ['full_name', 'email', 'password'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final TapGestureRecognizer _openTerms;

  bool _acceptedTerms = false;
  bool _showTermsError = false;

  @override
  void initState() {
    super.initState();
    _openTerms = TapGestureRecognizer()..onTap = _showLegal;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionController>().clearError();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _openTerms.dispose();
    super.dispose();
  }

  void _showLegal() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const LegalPage()),
    );
  }

  Future<void> _submit() async {
    final fieldsAreValid = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_acceptedTerms);
    if (!fieldsAreValid || !_acceptedTerms) return;
    FocusScope.of(context).unfocus();

    final created = await context.read<SessionController>().signUp(
      fullName: _name.text,
      email: _email.text,
      password: _password.text,
    );
    if (created && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final failure = session.failure;
    // Erros que o servidor atribuiu a um campo aparecem no próprio campo; os
    // demais (inclusive de um campo que esta tela não tem), no aviso do topo.
    final serverFields = failure is ValidationFailure
        ? failure.fieldErrors
        : const <String, String>{};
    final hasFieldError = _formFields.any(serverFields.containsKey);

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            // Ao voltar a digitar, o erro devolvido pelo servidor some: ele
            // era sobre o que foi enviado antes.
            onChanged: session.clearError,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (failure != null && !hasFieldError) ...[
                    FormErrorBanner(message: failure.message),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: validateFullName,
                    forceErrorText: serverFields['full_name'],
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    validator: validateEmail,
                    forceErrorText: serverFields['email'],
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _password,
                    label: 'Senha',
                    isNewPassword: true,
                    textInputAction: TextInputAction.next,
                    validator: validateNewPassword,
                    helperText: 'Pelo menos $passwordMinLength caracteres.',
                    serverError: serverFields['password'],
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _confirmation,
                    label: 'Repita a senha',
                    isNewPassword: true,
                    validator: (value) =>
                        validatePasswordConfirmation(value, _password.text),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _acceptedTerms,
                    onChanged: (value) => setState(() {
                      _acceptedTerms = value ?? false;
                      if (_acceptedTerms) _showTermsError = false;
                    }),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text.rich(
                      TextSpan(
                        style: context.text.body,
                        children: [
                          const TextSpan(text: 'Li e aceito os '),
                          TextSpan(
                            text: 'Termos de Uso e a Política de Privacidade',
                            style: TextStyle(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: _openTerms,
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    subtitle: _showTermsError
                        ? Semantics(
                            liveRegion: true,
                            child: Text(
                              'É preciso aceitar para criar a conta.',
                              style: context.text.caption.copyWith(
                                color: context.colors.danger,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Criar conta',
                    isLoading: session.isBusy,
                    onPressed: _submit,
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
