import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/utils/brazilian_documents.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/form_widgets.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:yvenist/features/client/shared/catalog_presentation.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';
import 'package:yvenist/features/vendor/presentation/controllers/vendor_controller.dart';

const int _maxPriceCents = 100000000; // R$ 1 milhão, o teto aceito pela API.
const int _descriptionMinLength = 20;

/// Cadastro de um salão em etapas. Cada etapa só avança depois de validada, e
/// nada é enviado antes da revisão final.
class HallCreationFlowPage extends StatefulWidget {
  const HallCreationFlowPage({super.key});

  @override
  State<HallCreationFlowPage> createState() => _HallCreationFlowPageState();
}

class _HallCreationFlowPageState extends State<HallCreationFlowPage> {
  static const int _stepCount = 6;
  static const Duration _stepAnimation = Duration(milliseconds: 300);

  final _pageController = PageController();
  final _formKeys = List.generate(_stepCount, (_) => GlobalKey<FormState>());
  int _step = 0;

  // Etapa 1: responsável
  PersonType _personType = PersonType.individual;
  final _document = TextEditingController();
  final _legalName = TextEditingController();

  // Etapa 2: o salão
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _area = TextEditingController();
  final _capacity = TextEditingController();
  final _neighborhood = TextEditingController();
  final _city = TextEditingController();
  String? _state;

  // Etapas 3 e 4: eventos e estrutura
  final Set<String> _eventTypes = {};
  bool _showEventTypeError = false;
  final Set<String> _amenities = {};
  late final Future<List<EventType>> _availableEventTypes;
  List<EventType> _loadedEventTypes = const [];

  // Etapa 5: preço
  final _price = TextEditingController();
  CancellationPolicy _policy = CancellationPolicy.flexible;

  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _availableEventTypes = context.read<CatalogRepository>().eventTypes()
      ..then((types) => _loadedEventTypes = types).ignore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<VendorController>().clearError();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in [
      _document,
      _legalName,
      _title,
      _description,
      _area,
      _capacity,
      _neighborhood,
      _city,
      _price,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isLastStep => _step == _stepCount - 1;

  bool get _hasInput =>
      _eventTypes.isNotEmpty ||
      _amenities.isNotEmpty ||
      [
        _document,
        _legalName,
        _title,
        _description,
        _city,
        _price,
      ].any((controller) => controller.text.trim().isNotEmpty);

  // ------------------------------------------------------------------
  // Navegação entre etapas
  // ------------------------------------------------------------------

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    _pageController.animateToPage(
      step,
      duration: _stepAnimation,
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (!_validateCurrentStep()) return;
    if (_isLastStep) {
      _submit();
    } else {
      _goTo(_step + 1);
    }
  }

  void _back() {
    if (_step > 0) {
      _goTo(_step - 1);
    } else {
      _exit();
    }
  }

  bool _validateCurrentStep() {
    final formIsValid = _formKeys[_step].currentState?.validate() ?? true;
    if (_step == 2) {
      setState(() => _showEventTypeError = _eventTypes.isEmpty);
      return _eventTypes.isNotEmpty;
    }
    return formIsValid;
  }

  /// Sair com dados preenchidos pede confirmação: nada é salvo até o envio.
  Future<void> _exit() async {
    if (!_hasInput || _submitted) {
      Navigator.pop(context);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair sem enviar?'),
        content: const Text('O que você preencheu será perdido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuar preenchendo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  // ------------------------------------------------------------------
  // Envio
  // ------------------------------------------------------------------

  HallListingDraft _buildDraft() {
    final neighborhood = _neighborhood.text.trim();
    return HallListingDraft(
      personType: _personType,
      document: normalizeDocument(_document.text),
      legalName: _legalName.text.trim(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      neighborhood: neighborhood.isEmpty ? null : neighborhood,
      city: _city.text.trim(),
      state: _state!,
      priceFromCents: parseBrlToCents(_price.text)!,
      areaM2: int.tryParse(_area.text.trim()),
      capacity: int.tryParse(_capacity.text.trim()),
      eventTypes: Set.of(_eventTypes),
      amenities: Set.of(_amenities),
      cancellationPolicy: _policy,
    );
  }

  Future<void> _submit() async {
    final vendor = context.read<VendorController>();
    final navigator = Navigator.of(context);
    final tabs = context.read<AppTabController>();

    final sent = await vendor.submitHall(_buildDraft());
    if (!sent || !mounted) return;
    setState(() => _submitted = true);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Anúncio enviado!'),
        content: const Text(
          'Vamos analisar os dados do seu salão. Você acompanha o andamento '
          'na aba Perfil.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    tabs.goTo(AppTab.profile);
    navigator.popUntil((route) => route.isFirst);
  }

  // ------------------------------------------------------------------
  // Validações dos campos
  // ------------------------------------------------------------------

  String? _validateDocument(String? value) {
    final document = normalizeDocument(value ?? '');
    final isCompany = _personType == PersonType.company;
    if (document.isEmpty) {
      return isCompany ? 'Informe o CNPJ.' : 'Informe o CPF.';
    }
    final isValid = isCompany ? isValidCnpj(document) : isValidCpf(document);
    if (!isValid) return isCompany ? 'CNPJ inválido.' : 'CPF inválido.';
    return null;
  }

  static String? Function(String?) _required(String message, {int min = 1}) {
    return (value) => (value?.trim().length ?? 0) < min ? message : null;
  }

  static String? _validateOptionalPositiveInt(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    return (number == null || number <= 0)
        ? 'Informe um número maior que zero.'
        : null;
  }

  static String? _validatePrice(String? value) {
    final cents = parseBrlToCents(value ?? '');
    if (cents == null) return 'Informe o preço, por exemplo 1500 ou 1.500,00.';
    if (cents <= 0) return 'O preço precisa ser maior que zero.';
    if (cents > _maxPriceCents) {
      return 'O preço máximo é ${formatBrl(_maxPriceCents)}.';
    }
    return null;
  }

  // ------------------------------------------------------------------
  // Tela
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<VendorController>();

    return PopScope(
      canPop: _step == 0 && (!_hasInput || _submitted),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: _step == 0 ? 'Sair do cadastro' : 'Etapa anterior',
            onPressed: _back,
          ),
          title: Semantics(
            label: 'Etapa ${_step + 1} de $_stepCount',
            child: ExcludeSemantics(
              child: LinearProgressIndicator(
                value: (_step + 1) / _stepCount,
                backgroundColor: context.colors.divider,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        // O rodapé vai até a borda de baixo da tela e guarda, dentro dele, o
        // espaço da barra de navegação do sistema.
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  // Só os botões mudam de etapa: arrastar pularia a validação.
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _step = index),
                  children: [
                    _stepLegal(),
                    _stepHall(),
                    _stepEventTypes(),
                    _stepAmenities(),
                    _stepPrice(),
                    _stepReview(vendor),
                  ],
                ),
              ),
              _BottomBar(
                canGoBack: _step > 0 && !vendor.isBusy,
                isLastStep: _isLastStep,
                isBusy: vendor.isBusy,
                onBack: _back,
                onNext: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepLegal() {
    final isCompany = _personType == PersonType.company;
    return _Step(
      formKey: _formKeys[0],
      title: 'Vamos começar pelo responsável',
      subtitle: 'Usamos esses dados para verificar quem está anunciando.',
      children: [
        SegmentedButton<PersonType>(
          segments: const [
            ButtonSegment(
              value: PersonType.individual,
              label: Text('Pessoa Física'),
            ),
            ButtonSegment(
              value: PersonType.company,
              label: Text('Pessoa Jurídica'),
            ),
          ],
          selected: {_personType},
          onSelectionChanged: (selection) =>
              setState(() => _personType = selection.first),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _document,
          // O CNPJ aceita letras desde julho de 2026.
          keyboardType: isCompany ? TextInputType.text : TextInputType.number,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z./\- ]')),
            LengthLimitingTextInputFormatter(18),
          ],
          validator: _validateDocument,
          decoration: InputDecoration(
            labelText: isCompany ? 'CNPJ' : 'CPF do responsável',
            helperText: 'Não aparece no anúncio.',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _legalName,
          textCapitalization: TextCapitalization.words,
          validator: _required(
            isCompany ? 'Informe a razão social.' : 'Informe o nome completo.',
            min: 3,
          ),
          decoration: InputDecoration(
            labelText: isCompany ? 'Razão social' : 'Nome completo',
          ),
        ),
      ],
    );
  }

  Widget _stepHall() {
    return _Step(
      formKey: _formKeys[1],
      title: 'Fale sobre o seu salão',
      children: [
        TextFormField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          maxLength: 120,
          validator: _required('Informe o nome do salão.', min: 3),
          decoration: const InputDecoration(
            labelText: 'Nome do salão',
            hintText: 'Ex.: Espaço Crystal',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 4,
          maxLength: 4000,
          validator: _required(
            'Descreva o espaço com pelo menos $_descriptionMinLength caracteres.',
            min: _descriptionMinLength,
          ),
          decoration: const InputDecoration(
            labelText: 'Descrição',
            hintText: 'Conte o que torna o seu espaço único',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _area,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateOptionalPositiveInt,
                decoration: const InputDecoration(labelText: 'Área (m²)'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateOptionalPositiveInt,
                decoration: const InputDecoration(labelText: 'Capacidade'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _neighborhood,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Bairro (opcional)'),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                validator: _required('Informe a cidade.', min: 2),
                decoration: const InputDecoration(labelText: 'Cidade'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _state,
                isExpanded: true,
                validator: (value) => value == null ? 'Escolha a UF.' : null,
                decoration: const InputDecoration(labelText: 'UF'),
                items: [
                  for (final state in brazilianStates)
                    DropdownMenuItem(value: state, child: Text(state)),
                ],
                onChanged: (value) => setState(() => _state = value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepEventTypes() {
    return _Step(
      formKey: _formKeys[2],
      title: 'Que eventos você aceita?',
      subtitle: 'Escolha pelo menos um.',
      children: [
        FutureBuilder<List<EventType>>(
          future: _availableEventTypes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final types = snapshot.data ?? const <EventType>[];
            if (types.isEmpty) {
              return const FormErrorBanner(
                message:
                    'Não foi possível carregar os tipos de evento. '
                    'Volte e tente de novo.',
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final type in types)
                  FilterChip(
                    label: Text(type.name),
                    selected: _eventTypes.contains(type.slug),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _eventTypes.add(type.slug)
                          : _eventTypes.remove(type.slug);
                      if (_eventTypes.isNotEmpty) _showEventTypeError = false;
                    }),
                  ),
              ],
            );
          },
        ),
        if (_showEventTypeError) ...[
          const SizedBox(height: 16),
          const FormErrorBanner(
            message: 'Escolha pelo menos um tipo de evento.',
          ),
        ],
      ],
    );
  }

  Widget _stepAmenities() {
    return _Step(
      formKey: _formKeys[3],
      title: 'O que o espaço oferece?',
      subtitle: 'Opcional. Marque o que estiver disponível.',
      children: [
        for (final option in amenityOptions)
          CheckboxListTile(
            title: Text(option.label),
            secondary: Icon(option.icon),
            value: _amenities.contains(option.slug),
            contentPadding: EdgeInsets.zero,
            onChanged: (checked) => setState(() {
              checked == true
                  ? _amenities.add(option.slug)
                  : _amenities.remove(option.slug);
            }),
          ),
      ],
    );
  }

  Widget _stepPrice() {
    return _Step(
      formKey: _formKeys[4],
      title: 'Quanto custa?',
      children: [
        TextFormField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
          ],
          validator: _validatePrice,
          decoration: const InputDecoration(
            labelText: 'Preço a partir de',
            prefixText: r'R$ ',
            helperText: 'Valor inicial por evento. Aparece no anúncio.',
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Política de cancelamento',
          style: context.text.body.copyWith(fontWeight: FontWeight.w700),
        ),
        RadioGroup<CancellationPolicy>(
          groupValue: _policy,
          onChanged: (value) => setState(() => _policy = value ?? _policy),
          child: Column(
            children: [
              for (final policy in CancellationPolicy.values)
                RadioListTile(
                  value: policy,
                  contentPadding: EdgeInsets.zero,
                  title: Text(policy.label),
                  subtitle: Text(policy.summary),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepReview(VendorController vendor) {
    final priceCents = parseBrlToCents(_price.text);
    final neighborhood = _neighborhood.text.trim();
    final location = [
      if (neighborhood.isNotEmpty) neighborhood,
      _city.text.trim(),
      ?_state,
    ].join(', ');
    final eventNames = [
      for (final type in _loadedEventTypes)
        if (_eventTypes.contains(type.slug)) type.name,
    ];
    final amenityNames = [
      for (final option in amenityOptions)
        if (_amenities.contains(option.slug)) option.label,
    ];

    return _Step(
      formKey: _formKeys[5],
      title: 'Confira antes de enviar',
      subtitle: 'Depois do envio, nossa equipe analisa os dados do salão.',
      children: [
        if (vendor.failure != null) ...[
          FormErrorBanner(message: vendor.failure!.message),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _ReviewRow(label: 'Responsável', value: _legalName.text.trim()),
              _ReviewRow(label: 'Salão', value: _title.text.trim()),
              _ReviewRow(label: 'Local', value: location),
              if (_capacity.text.trim().isNotEmpty)
                _ReviewRow(
                  label: 'Capacidade',
                  value: '${_capacity.text.trim()} pessoas',
                ),
              if (_area.text.trim().isNotEmpty)
                _ReviewRow(label: 'Área', value: '${_area.text.trim()} m²'),
              _ReviewRow(label: 'Eventos', value: eventNames.join(', ')),
              _ReviewRow(
                label: 'Estrutura',
                value: amenityNames.isEmpty
                    ? 'Não informada'
                    : amenityNames.join(', '),
              ),
              _ReviewRow(
                label: 'Preço a partir de',
                value: priceCents == null ? '' : formatBrl(priceCents),
              ),
              _ReviewRow(label: 'Cancelamento', value: _policy.label),
            ],
          ),
        ),
      ],
    );
  }
}

/// Moldura de uma etapa: título, explicação e os campos, com rolagem.
class _Step extends StatelessWidget {
  const _Step({
    required this.formKey,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: context.text.sectionTitle.copyWith(fontSize: 24),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: context.text.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canGoBack,
    required this.isLastStep,
    required this.isBusy,
    required this.onBack,
    required this.onNext,
  });

  final bool canGoBack;
  final bool isLastStep;
  final bool isBusy;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: context.withSystemBottomInset(const EdgeInsets.all(16)),
      decoration: BoxDecoration(
        color: colors.surface,
        // No tema escuro a sombra não se vê: uma linha separa a barra.
        border: colors.isDark
            ? Border(top: BorderSide(color: colors.divider))
            : null,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: canGoBack ? onBack : null,
            child: const Text('Voltar'),
          ),
          const SizedBox(width: 12),
          // Ocupa o espaço que sobra: com letras grandes (acessibilidade) o
          // rótulo quebra a linha em vez de estourar a largura da tela.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: isBusy ? null : onNext,
                child: isBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        isLastStep ? 'Enviar anúncio' : 'Avançar',
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.text.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.text.body,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
