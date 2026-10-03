import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/app_network_image.dart';
import 'package:yvenist/core/widgets/form_widgets.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_item_catalog.dart';
import 'package:yvenist/features/party_maker/domain/rules/item_configuration_spec.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/configured_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/models/party_target.dart';
import 'package:yvenist/features/party_maker/presentation/party_presentation.dart';
import 'package:yvenist/features/party_maker/presentation/widgets/event_details_fields.dart';

/// A configuração de um item da festa: o que a categoria dele pede, e só isso.
///
/// É a mesma tela para pôr um anúncio na festa e para alterar um item que já
/// está nela (que abre com o que a pessoa tinha informado). Nada entra na
/// festa antes de o formulário passar pelas regras; os campos vêm de
/// `ItemConfigurationSpec`, e não desta tela.
class ItemConfigurationPage extends StatefulWidget {
  /// Para pôr o anúncio [listingId] na festa [target]. Fecha devolvendo a
  /// festa (`Party`) em que o item entrou.
  const ItemConfigurationPage.add({
    super.key,
    required String this.listingId,
    required this.itemName,
    required PartyTarget this.target,
    this.recommendedBy,
  }) : partyId = null,
       itemId = null,
       notice = null;

  /// Para alterar o item [itemId] da festa [partyId]. Fecha devolvendo `true`
  /// quando as alterações foram gravadas.
  const ItemConfigurationPage.edit({
    super.key,
    required PartyId this.partyId,
    required PartyItemId this.itemId,
    required this.itemName,
    this.notice,
  }) : listingId = null,
       target = null,
       recommendedBy = null;

  final String? listingId;
  final String itemName;
  final PartyTarget? target;

  /// Um recado no topo do formulário, dizendo por que a pessoa veio parar aqui.
  final String? notice;

  /// O item da festa que recomendou este, quando ele veio de uma indicação.
  final PartyItemId? recommendedBy;

  final PartyId? partyId;
  final PartyItemId? itemId;

  bool get isEditing => itemId != null;

  @override
  State<ItemConfigurationPage> createState() => _ItemConfigurationPageState();
}

/// O que a pessoa preencheu para um item (o principal ou um serviço próprio).
class _ItemInput {
  _ItemInput(this.draft, {required bool isOwnService, PartyItem? existing})
    : spec = ItemConfigurationSpec.of(
        category: draft.category,
        pricingModel: draft.pricing.model,
        isOwnService: isOwnService,
      ),
      quantity = TextEditingController(
        text: '${existing?.quantity.value ?? 1}',
      ) {
    for (final field in spec.fields) {
      final value = existing?.configuration[field.key];
      if (field.kind == ConfigFieldKind.choice) {
        choices[field.key] = value is String ? value : null;
      } else {
        texts[field.key] = TextEditingController(text: value?.toString() ?? '');
      }
    }
  }

  final PartyItemDraft draft;
  final ItemConfigurationSpec spec;
  final TextEditingController quantity;
  final Map<String, TextEditingController> texts = {};
  final Map<String, String?> choices = {};

  int get quantityValue => int.tryParse(quantity.text.trim()) ?? 1;

  int? get durationHours =>
      int.tryParse(texts[ItemConfiguration.durationKey]?.text.trim() ?? '');

  /// A configuração como foi preenchida, pela chave de cada campo. Quem
  /// confere e limpa são as regras da categoria.
  Map<String, Object?> get raw => {
    for (final field in spec.fields)
      field.key: switch (field.kind) {
        ConfigFieldKind.choice => choices[field.key],
        ConfigFieldKind.integer => _integer(texts[field.key]!.text),
        ConfigFieldKind.text => texts[field.key]!.text,
      },
  };

  /// Um número, quando é um; senão o texto como veio, para a regra do campo
  /// dizer o que há de errado com ele.
  static Object? _integer(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed) ?? trimmed;
  }

  Money? estimate({required int? guests}) {
    return draft.pricing.estimate(
      guests: guests,
      hours: durationHours,
      quantity: quantityValue,
    );
  }

  ConfiguredItem toConfigured({
    List<ConfiguredItem> ownServices = const [],
    PartyItemId? recommendedBy,
  }) {
    return ConfiguredItem(
      draft: draft,
      quantity: quantityValue,
      configuration: raw,
      ownServices: ownServices,
      recommendedBy: recommendedBy,
    );
  }

  void addListener(VoidCallback listener) {
    quantity.addListener(listener);
    for (final controller in texts.values) {
      controller.addListener(listener);
    }
  }

  void dispose() {
    quantity.dispose();
    for (final controller in texts.values) {
      controller.dispose();
    }
  }
}

/// Tudo o que a tela precisa ter em mãos antes de mostrar o formulário.
class _Loaded {
  _Loaded({
    required this.item,
    required this.services,
    required this.selected,
    required this.eventTypes,
    required this.event,
    required this.party,
    required this.canChangeServices,
    required this.hasHiddenServices,
  });

  final _ItemInput item;

  /// Os serviços do próprio anunciante, na ordem do anúncio.
  final List<_ItemInput> services;

  /// Os que a pessoa quis junto. Os obrigatórios estão sempre aqui.
  final Set<ExternalRef> selected;
  final List<EventTypeOption> eventTypes;
  final EventDetailsInput event;

  /// A festa em que o item está ou vai entrar. Nula para uma festa nova.
  final Party? party;

  /// Falso quando o catálogo não respondeu ao abrir um item para alterar: a
  /// configuração pode mudar, mas a escolha dos serviços fica como está.
  final bool canChangeServices;

  /// O item tem serviços na festa que não puderam ser listados agora.
  final bool hasHiddenServices;

  void dispose() {
    item.dispose();
    for (final service in services) {
      service.dispose();
    }
    event.dispose();
  }
}

class _ItemConfigurationPageState extends State<ItemConfigurationPage> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();

  _Loaded? _loaded;
  String? _loadError;
  String? _submitError;

  // Depois da primeira tentativa com erro, o formulário confere de novo a cada
  // mudança: o erro de um campo some assim que o campo é corrigido.
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loaded?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------------
  // Carga
  // ------------------------------------------------------------------

  Future<void> _load() async {
    setState(() => _loadError = null);
    final controller = context.read<PartyMakerController>();
    final catalog = context.read<PartyItemCatalog>();

    final target = widget.target;
    final partyId =
        widget.partyId ??
        (target is ExistingPartyTarget ? target.partyId : null);
    final party = partyId == null ? null : controller.partyById(partyId);
    final existing = widget.itemId == null
        ? null
        : party?.budget.findById(widget.itemId!);
    if (widget.isEditing && existing == null) {
      // Outro aparelho tirou o item enquanto a tela era aberta.
      setState(() => _loadError = const PartyItemNotFound().message);
      return;
    }

    try {
      final (draft, fromCatalog) = await _draft(catalog, existing);
      // Os tipos de evento são um detalhe: sem eles o formulário funciona.
      final eventTypes = await catalog.eventTypes().catchError(
        (Object _) => const <EventTypeOption>[],
      );
      if (!mounted) return;

      final children = existing == null || party == null
          ? const <PartyItem>[]
          : party.budget.childrenOf(existing.id);
      PartyItem? childFor(PartyItemDraft service) {
        for (final child in children) {
          if (child.externalRef == service.externalRef) return child;
        }
        return null;
      }

      final item = _ItemInput(
        draft,
        isOwnService: existing?.relation.isOwnService ?? false,
        existing: existing,
      );
      final services = [
        for (final service in draft.ownServices)
          _ItemInput(service, isOwnService: true, existing: childFor(service)),
      ];
      final loaded = _Loaded(
        item: item,
        services: services,
        selected: {
          for (final service in draft.ownServices)
            if (service.isRequired || childFor(service) != null)
              service.externalRef,
        },
        eventTypes: eventTypes,
        event: EventDetailsInput(
          eventType: party?.eventType,
          eventDate: party?.eventDate?.value,
          guestCount: party?.guestCount?.value,
        ),
        party: party,
        canChangeServices: fromCatalog,
        hasHiddenServices:
            !fromCatalog &&
            children.any((child) => child.relation.isOwnService),
      );
      item.addListener(_refresh);
      for (final service in services) {
        service.addListener(_refresh);
      }
      setState(() => _loaded = loaded);
    } catch (error) {
      if (mounted) setState(() => _loadError = describeFailure(error));
    }
  }

  /// O que o catálogo diz do item agora e se a resposta veio mesmo dele.
  ///
  /// Para alterar um item, o catálogo só serve para listar os serviços
  /// próprios: se ele não responder (ou o anúncio tiver saído do ar), a
  /// configuração do item continua podendo ser alterada com o que a festa já
  /// guarda.
  Future<(PartyItemDraft, bool)> _draft(
    PartyItemCatalog catalog,
    PartyItem? existing,
  ) async {
    if (existing == null) {
      return (await catalog.draftFor(widget.listingId!), true);
    }

    final stored = PartyItemDraft(
      externalRef: existing.externalRef,
      category: existing.category,
      name: existing.nameSnapshot,
      pricing: existing.pricing,
      imageUrl: existing.imageUrlSnapshot,
      capacity: existing.capacity,
    );
    if (!existing.externalRef.isListing) return (stored, false);
    try {
      final current = await catalog.draftFor(existing.externalRef.id);
      // O nome e o preço continuam sendo os de quando o item entrou.
      return (
        PartyItemDraft(
          externalRef: stored.externalRef,
          category: stored.category,
          name: stored.name,
          pricing: stored.pricing,
          imageUrl: stored.imageUrl,
          capacity: stored.capacity,
          ownServices: current.ownServices,
        ),
        true,
      );
    } on AppFailure {
      return (stored, false);
    }
  }

  // ------------------------------------------------------------------
  // Envio
  // ------------------------------------------------------------------

  bool _needsEvent(_Loaded loaded) {
    return loaded.item.spec.requiresEventDetails || _needsGuests(loaded);
  }

  bool _needsGuests(_Loaded loaded) {
    return [
      loaded.item,
      for (final service in loaded.services)
        if (loaded.selected.contains(service.draft.externalRef)) service,
    ].any((input) => input.draft.pricing.model == PricingModel.perPerson);
  }

  /// Os dados do evento como ficaram no formulário, ou `null` quando ele não
  /// foi mostrado e a festa já existe: aí nada do evento muda.
  EventDetails? _eventDetails(_Loaded loaded) {
    final party = loaded.party;
    final target = widget.target;
    final title = party?.title.value ?? (target as NewPartyTarget).title;

    if (!_needsEvent(loaded)) {
      return party == null ? EventDetails(title: PartyTitle(title)) : null;
    }
    final date = loaded.event.eventDate;
    final guests = loaded.event.guestCount;
    return EventDetails(
      title: PartyTitle(title),
      eventType: loaded.event.eventType,
      eventDate: date == null ? null : EventDate(date),
      guestCount: guests == null ? null : GuestCount(guests),
    );
  }

  Future<void> _submit() async {
    final loaded = _loaded!;
    setState(() => _submitError = null);
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      setState(() => _showErrors = true);
      // O campo com problema pode estar fora da tela: a rolagem vai até ele.
      await Scrollable.ensureVisible(
        invalid.first.context,
        alignment: 0.2,
        duration: const Duration(milliseconds: 250),
      );
      return;
    }
    if (!mounted) return;

    final controller = context.read<PartyMakerController>();
    final navigator = Navigator.of(context);
    final ownServices = [
      for (final service in loaded.services)
        if (loaded.selected.contains(service.draft.externalRef))
          service.toConfigured(),
    ];

    final Object? result;
    try {
      final details = _eventDetails(loaded);
      final party = loaded.party;
      if (widget.isEditing) {
        final saved = await controller.updateItem(
          widget.partyId!,
          widget.itemId!,
          quantity: loaded.item.quantityValue,
          configuration: loaded.item.raw,
          ownServices: loaded.canChangeServices ? ownServices : null,
          eventDetails: details,
        );
        result = saved ? true : null;
      } else {
        final selection = loaded.item.toConfigured(
          ownServices: ownServices,
          recommendedBy: widget.recommendedBy,
        );
        result = party == null
            ? await controller.addItemToNewParty(details!, selection)
            : await controller.addItem(
                party.id,
                selection,
                eventDetails: details,
              );
      }
    } on PartyDomainException catch (error) {
      // Um valor que nem chega a virar dado da festa (um nome vazio, um
      // número de convidados fora do limite).
      _fail(error.message);
      return;
    }

    if (!mounted) return;
    if (result == null) {
      _fail(controller.error ?? 'Não foi possível salvar o item.');
      return;
    }
    navigator.pop(result);
  }

  void _fail(String message) {
    setState(() => _submitError = message);
    // O aviso fica no topo do formulário: traz ele para a tela.
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  // ------------------------------------------------------------------
  // Tela
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final loaded = _loaded;
    final loadError = _loadError;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Alterar item' : 'Adicionar à festa'),
      ),
      body: loaded != null
          ? _form(loaded)
          : loadError != null
          ? ErrorStateView(message: loadError, onRetry: _load)
          : LoadingView(label: 'Carregando ${widget.itemName}'),
    );
  }

  Widget _form(_Loaded loaded) {
    final isBusy = context.watch<PartyMakerController>().isBusy;
    final draft = loaded.item.draft;
    final needsEvent = _needsEvent(loaded);
    final needsDate = loaded.item.spec.requiresEventDetails;
    final guests = needsEvent
        ? loaded.event.guestCount
        : loaded.party?.guestCount?.value;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              autovalidateMode: _showErrors
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              // Uma coluna, e não uma lista preguiçosa: a validação só enxerga
              // os campos que estão montados, e todos têm de ser conferidos,
              // inclusive os que estão fora da tela.
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_submitError != null) ...[
                      FormErrorBanner(message: _submitError!),
                      const SizedBox(height: 16),
                    ],
                    if (widget.notice != null) ...[
                      _Notice(widget.notice!),
                      const SizedBox(height: 16),
                    ],
                    _ItemHeader(draft: draft),
                    if (needsEvent) ...[
                      const _SectionTitle(
                        'Dados do evento',
                        subtitle: 'Valem para a festa inteira.',
                      ),
                      EventDetailsFields(
                        input: loaded.event,
                        eventTypes: loaded.eventTypes,
                        requireDate: needsDate,
                        requireGuests: true,
                        // Um item cobrado por pessoa só precisa saber quantas
                        // são: a data fica para a tela do evento.
                        guestsOnly: !needsDate,
                        maxGuests:
                            draft.capacity ??
                            loaded.party?.budget.venue?.capacity,
                        onChanged: _refresh,
                      ),
                    ],
                    const _SectionTitle('Sobre este item'),
                    _ItemFields(input: loaded.item, onChanged: _refresh),
                    if (loaded.services.isNotEmpty) ...[
                      _SectionTitle(
                        'Serviços de ${draft.name}',
                        subtitle: 'Oferecidos pelo próprio anunciante.',
                      ),
                      for (final service in loaded.services)
                        _OwnServiceTile(
                          input: service,
                          isSelected: loaded.selected.contains(
                            service.draft.externalRef,
                          ),
                          onChanged: (selected) => setState(() {
                            selected
                                ? loaded.selected.add(service.draft.externalRef)
                                : loaded.selected.remove(
                                    service.draft.externalRef,
                                  );
                          }),
                          onFieldChanged: _refresh,
                        ),
                    ],
                    if (loaded.hasHiddenServices)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Não foi possível consultar o anúncio agora: os '
                          'serviços dele que estão na festa ficam como estão.',
                          style: context.text.caption,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          _EstimateBar(
            estimates: [
              loaded.item.estimate(guests: guests),
              for (final service in loaded.services)
                if (loaded.selected.contains(service.draft.externalRef))
                  service.estimate(guests: guests),
            ],
            actionLabel: widget.isEditing
                ? 'Salvar alterações'
                : 'Adicionar à festa',
            isBusy: isBusy,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

/// O item que está sendo configurado: foto, nome, categoria e como cobra.
class _ItemHeader extends StatelessWidget {
  const _ItemHeader({required this.draft});

  final PartyItemDraft draft;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final capacity = draft.capacity;
    final minimum = draft.pricing.minimum;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AppNetworkImage(
            url: draft.imageUrl,
            width: 72,
            height: 72,
            fallbackIcon: draft.category.icon,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(draft.name, style: text.sectionTitle),
              ),
              const SizedBox(height: 2),
              Text(draft.category.groupLabel, style: text.caption),
              const SizedBox(height: 4),
              Text(
                pricingLabel(draft.pricing),
                style: text.body.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (minimum != null)
                Text(
                  'Valor mínimo de ${formatBrl(minimum.cents)}',
                  style: text.caption,
                ),
              if (capacity != null)
                Text('Comporta até $capacity pessoas', style: text.caption),
            ],
          ),
        ),
      ],
    );
  }
}

/// Um recado neutro: explica, não acusa um erro.
class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.info_outline,
              size: 20,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.text.body.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: context.text.cardTitle),
          ),
          if (subtitle != null) Text(subtitle!, style: context.text.caption),
        ],
      ),
    );
  }
}

/// Os campos que a categoria do item pede, montados a partir da tabela de
/// regras: a tela não sabe quais são.
class _ItemFields extends StatelessWidget {
  const _ItemFields({
    required this.input,
    required this.onChanged,
    this.fields,
  });

  final _ItemInput input;
  final VoidCallback onChanged;

  /// Quais campos mostrar. Sem isto, todos os que o item pede.
  final List<ConfigField>? fields;

  @override
  Widget build(BuildContext context) {
    final quantityLabel = input.spec.quantityLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quantityLabel != null) ...[
          TextFormField(
            controller: input.quantity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: _validateQuantity,
            decoration: InputDecoration(labelText: quantityLabel),
          ),
          const SizedBox(height: 16),
        ],
        for (final field in fields ?? input.spec.fields) ...[
          _ConfigFieldInput(field: field, input: input, onChanged: onChanged),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  static String? _validateQuantity(String? value) {
    final quantity = int.tryParse(value?.trim() ?? '');
    if (quantity == null || quantity < 1 || quantity > Quantity.max) {
      return 'Informe uma quantidade de 1 a ${Quantity.max}.';
    }
    return null;
  }
}

class _ConfigFieldInput extends StatelessWidget {
  const _ConfigFieldInput({
    required this.field,
    required this.input,
    required this.onChanged,
  });

  final ConfigField field;
  final _ItemInput input;
  final VoidCallback onChanged;

  /// A regra do campo, aplicada ao que a pessoa digitou: a mesma que vale na
  /// hora de o item entrar na festa.
  String? _validate(Object? value) {
    return field.problemWith(
      value is String && value.trim().isEmpty ? null : value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = field.isRequired ? field.label : '${field.label} (opcional)';

    switch (field.kind) {
      case ConfigFieldKind.choice:
        return DropdownButtonFormField<String?>(
          initialValue: input.choices[field.key],
          isExpanded: true,
          validator: _validate,
          decoration: InputDecoration(labelText: label),
          items: [
            if (!field.isRequired)
              const DropdownMenuItem(child: Text('Não informar')),
            for (final option in field.options)
              DropdownMenuItem(value: option.value, child: Text(option.label)),
          ],
          onChanged: (value) {
            input.choices[field.key] = value;
            onChanged();
          },
        );
      case ConfigFieldKind.integer:
        return TextFormField(
          controller: input.texts[field.key],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) => _validate(_ItemInput._integer(value ?? '')),
          decoration: InputDecoration(labelText: label, hintText: field.hint),
        );
      case ConfigFieldKind.text:
        return TextFormField(
          controller: input.texts[field.key],
          maxLength: field.maxLength,
          maxLines: field.isMultiline ? 3 : 1,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => _validate(value?.trim()),
          decoration: InputDecoration(
            labelText: label,
            hintText: field.hint,
            alignLabelWithHint: field.isMultiline,
          ),
        );
    }
  }
}

/// Um serviço do próprio anunciante: a pessoa marca se quer junto. O que é
/// obrigatório já vem marcado e não pode ser desmarcado.
class _OwnServiceTile extends StatelessWidget {
  const _OwnServiceTile({
    required this.input,
    required this.isSelected,
    required this.onChanged,
    required this.onFieldChanged,
  });

  final _ItemInput input;
  final bool isSelected;
  final ValueChanged<bool> onChanged;
  final VoidCallback onFieldChanged;

  @override
  Widget build(BuildContext context) {
    final draft = input.draft;
    final text = context.text;
    final description = draft.description;
    // As observações de um serviço vão junto com as do item principal: aqui
    // só entra o que o preço dele usa (a duração, a quantidade).
    final fields = [
      for (final field in input.spec.fields)
        if (field.key != ItemConfiguration.notesKey) field,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: isSelected,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: draft.isRequired
              ? null
              : (selected) => onChanged(selected ?? false),
          title: Text(draft.name, style: text.body),
          subtitle: Text(
            [
              pricingLabel(draft.pricing),
              if (draft.isRequired) 'Obrigatório',
              ?description,
            ].join(' · '),
            style: text.caption,
          ),
        ),
        if (isSelected && (fields.isNotEmpty || input.spec.allowsQuantity))
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 8),
            child: _ItemFields(
              input: input,
              fields: fields,
              onChanged: onFieldChanged,
            ),
          ),
      ],
    );
  }
}

/// O rodapé: quanto este item soma à estimativa e o botão de confirmar.
class _EstimateBar extends StatelessWidget {
  const _EstimateBar({
    required this.estimates,
    required this.actionLabel,
    required this.isBusy,
    required this.onSubmit,
  });

  /// A estimativa do item e a de cada serviço escolhido; nulo é "sem como
  /// estimar".
  final List<Money?> estimates;
  final String actionLabel;
  final bool isBusy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final known = estimates.whereType<Money>().toList();
    final unpriced = estimates.length - known.length;
    final total = known.fold<int>(0, (sum, amount) => sum + amount.cents);
    final value = known.isEmpty
        ? onRequestLabel
        : unpriced == 0
        ? formatBrl(total)
        : '${formatBrl(total)} + $unpriced sob consulta';

    return Container(
      padding: context.withSystemBottomInset(const EdgeInsets.all(16)),
      decoration: BoxDecoration(
        color: colors.surface,
        // No tema escuro a sombra não se vê: uma linha separa o rodapé.
        border: colors.isDark
            ? Border(top: BorderSide(color: colors.divider))
            : null,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text('Estimativa deste item', style: text.body),
                Text(
                  value,
                  style: text.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'O valor final vem no orçamento do fornecedor.',
            style: text.caption,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: actionLabel,
            onPressed: onSubmit,
            isLoading: isBusy,
          ),
        ],
      ),
    );
  }
}
