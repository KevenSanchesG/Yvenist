import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/widgets/form_widgets.dart';
import 'package:yvenist/features/auth/domain/auth_validators.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';

/// Dados pessoais da conta: nome, telefone e data de nascimento.
class PersonalDataPage extends StatefulWidget {
  const PersonalDataPage({super.key});

  @override
  State<PersonalDataPage> createState() => _PersonalDataPageState();
}

class _PersonalDataPageState extends State<PersonalDataPage> {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  DateTime? _birthDate;

  late final String _initialName;
  late final String _initialPhone;
  late final DateTime? _initialBirthDate;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionController>();
    final user = session.user!;
    _initialName = user.fullName;
    _initialPhone = formatPhone(user.phone);
    _initialBirthDate = user.birthDate;

    _name = TextEditingController(text: _initialName);
    _phone = TextEditingController(text: _initialPhone);
    _birthDate = _initialBirthDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) session.clearError();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _name.text.trim() != _initialName ||
      _phone.text.trim() != _initialPhone ||
      _birthDate != _initialBirthDate;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final messenger = ScaffoldMessenger.of(context);
    final saved = await context.read<SessionController>().updateProfile(
      fullName: _name.text,
      phone: _phone.text,
      birthDate: _birthDate,
    );
    if (!saved || !mounted) return;

    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Dados salvos.')));
  }

  /// Sair com alterações não salvas pede confirmação, para não perdê-las.
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('O que você mudou ainda não foi salvo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    // A conta pode ter sido encerrada com esta tela aberta.
    if (user == null) return const Scaffold(body: SizedBox.shrink());

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Dados Pessoais')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (session.error != null) ...[
                    FormErrorBanner(message: session.error!),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: validateFullName,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Só exibe: não é um campo de texto, para o "próximo" do
                  // teclado ir do nome direto para o telefone.
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      helperText:
                          'O e-mail identifica a conta e não pode ser '
                          'alterado.',
                      helperMaxLines: 2,
                      suffixIcon: Icon(Icons.lock_outline),
                    ),
                    child: Text(user.email),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: validatePhone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone (opcional)',
                      hintText: '(21) 99999-9999',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Abre o calendário: a data é escolhida, não digitada, então
                  // não há formato errado para corrigir depois.
                  InkWell(
                    onTap: _pickBirthDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Data de nascimento (opcional)',
                        suffixIcon: _birthDate == null
                            ? const Icon(Icons.calendar_today_outlined)
                            : IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: 'Limpar data de nascimento',
                                onPressed: () =>
                                    setState(() => _birthDate = null),
                              ),
                      ),
                      child: Text(
                        _birthDate == null
                            ? 'Não informada'
                            : _dateFormat.format(_birthDate!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: 'Salvar',
                    isLoading: session.isBusy,
                    onPressed: _hasChanges ? _save : null,
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
