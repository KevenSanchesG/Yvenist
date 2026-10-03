import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_theme.dart';

/// Botão principal de um formulário. Enquanto [isLoading] ele fica desabilitado
/// e mostra o progresso, o que também impede o envio duplicado.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? Semantics(
                label: 'Enviando',
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Mensagem de erro de um formulário, anunciada por leitores de tela assim
/// que aparece.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.tint(colors.danger),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.error_outline, color: colors.danger, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: context.text.body.copyWith(color: colors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de formulário que abre um seletor (calendário, relógio) em vez do
/// teclado: um botão com a aparência dos campos em volta.
///
/// Não é um `TextFormField` só de leitura com `onTap`. O toque do dedo
/// funcionaria, mas o Flutter não publica ação nenhuma de um campo só de
/// leitura: para o leitor de tela ele seria um texto, sem nada para acionar.
/// Aqui o rótulo, o valor e o toque são um botão só.
class PickerFormField extends StatelessWidget {
  const PickerFormField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.validator,
  });

  final String label;

  /// O que foi escolhido, já escrito para a tela; vazio se nada foi.
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  /// A mensagem de erro, ou `null` se o campo está certo.
  final String? Function()? validator;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => validator?.call(),
      builder: (field) => Semantics(
        container: true,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            isEmpty: value.isEmpty,
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: Icon(icon),
              errorText: field.errorText,
            ),
            // Sempre um texto, mesmo vazio, e no estilo do que se digita nos
            // campos vizinhos: assim o campo tem a altura deles, com ou sem
            // valor.
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      ),
    );
  }
}

/// Campo de senha com botão para mostrar/ocultar o que foi digitado.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.isNewPassword = false,
    this.helperText,
    this.serverError,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  /// Diz ao gerenciador de senhas se é para preencher ou para sugerir uma.
  final bool isNewPassword;
  final String? helperText;

  /// Erro que o servidor atribuiu a este campo, mostrado como os de validação.
  final String? serverError;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  // Fora da sequência de foco: o "próximo" do teclado tem de ir para o campo
  // seguinte. Parando no botão do olho, o teclado fechava no meio do
  // formulário. O botão continua respondendo ao toque e a leitores de tela.
  final FocusNode _toggleFocus = FocusNode(skipTraversal: true);

  @override
  void dispose() {
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      forceErrorText: widget.serverError,
      autofillHints: [
        widget.isNewPassword
            ? AutofillHints.newPassword
            : AutofillHints.password,
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        suffixIcon: IconButton(
          focusNode: _toggleFocus,
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          tooltip: _obscured ? 'Mostrar senha' : 'Ocultar senha',
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
