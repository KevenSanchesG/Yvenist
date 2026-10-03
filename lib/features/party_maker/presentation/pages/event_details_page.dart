import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/form_widgets.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_item_catalog.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/widgets/event_details_fields.dart';

/// Os dados do evento: o nome da festa, o tipo, quando é e para quantas
/// pessoas. Serve para criar uma festa e para alterar uma que já existe.
class EventDetailsPage extends StatefulWidget {
  /// Para criar uma festa nova. Fecha devolvendo `true` quando ela foi criada.
  const EventDetailsPage.create({super.key}) : partyId = null;

  /// Para alterar a festa [partyId].
  const EventDetailsPage.edit({super.key, required PartyId this.partyId});

  final PartyId? partyId;

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final Party? _party;
  late final TextEditingController _title;
  late final EventDetailsInput _event;

  List<EventTypeOption> _eventTypes = const [];
  String? _error;

  // Depois da primeira tentativa com erro, o formulário confere de novo a cada
  // mudança: o erro de um campo some assim que o campo é corrigido.
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final partyId = widget.partyId;
    _party = partyId == null
        ? null
        : context.read<PartyMakerController>().partyById(partyId);
    _title = TextEditingController(text: _party?.title.value ?? '');
    _event = EventDetailsInput(
      eventType: _party?.eventType,
      eventDate: _party?.eventDate?.value,
      guestCount: _party?.guestCount?.value,
    );
    _loadEventTypes();
  }

  @override
  void dispose() {
    _title.dispose();
    _event.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Os tipos de evento são opcionais: se o catálogo não responder, o campo
  /// fica só com "Não informar" e o resto do formulário funciona.
  Future<void> _loadEventTypes() async {
    try {
      final types = await context.read<PartyItemCatalog>().eventTypes();
      if (mounted) setState(() => _eventTypes = types);
    } catch (_) {
      // Sem os tipos, a pessoa segue sem escolher um.
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
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
    final partyId = widget.partyId;

    final bool saved;
    try {
      final date = _event.eventDate;
      final guests = _event.guestCount;
      final details = EventDetails(
        title: PartyTitle(_title.text),
        eventType: _event.eventType,
        eventDate: date == null ? null : EventDate(date),
        guestCount: guests == null ? null : GuestCount(guests),
      );
      saved = partyId == null
          ? await controller.createParty(details) != null
          : await controller.updateEventDetails(partyId, details);
    } on PartyDomainException catch (error) {
      // Um valor que nem chega a virar dado da festa (um número de convidados
      // fora do limite).
      _fail(error.message);
      return;
    }

    if (!mounted) return;
    if (saved) {
      navigator.pop(true);
    } else {
      _fail(controller.error ?? 'Não foi possível salvar os dados do evento.');
    }
  }

  void _fail(String message) {
    setState(() => _error = message);
    // O aviso fica no topo do formulário: traz ele para a tela.
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = context.watch<PartyMakerController>().isBusy;
    final party = _party;
    final isEditing = widget.partyId != null;
    // Mudar o evento descarta os valores que os fornecedores já informaram:
    // a pessoa fica sabendo antes de mudar.
    final hasQuotes =
        party != null && party.budget.items.any((item) => item.quote.isQuoted);
    final capacity = party?.budget.venue?.capacity;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Dados do evento' : 'Nova festa')),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          autovalidateMode: _showErrors
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          // Uma coluna, e não uma lista preguiçosa: a validação só enxerga os
          // campos que estão montados, e com letras grandes o nome da festa
          // sai da tela antes de a pessoa chegar ao botão.
          child: SingleChildScrollView(
            controller: _scroll,
            padding: context.withSystemBottomInset(const EdgeInsets.all(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  FormErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],
                if (!isEditing) ...[
                  Text(
                    'Dê um nome para a festa. A data e os convidados podem '
                    'ficar para depois: você informa quando escolher o salão '
                    'ou pedir o orçamento.',
                    style: context.text.body.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _title,
                  autofocus: !isEditing,
                  maxLength: PartyTitle.maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Dê um nome para a festa.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Nome da festa',
                    hintText: 'Ex.: 15 anos da Maria',
                  ),
                ),
                const SizedBox(height: 8),
                EventDetailsFields(
                  input: _event,
                  eventTypes: _eventTypes,
                  maxGuests: capacity,
                  // A data e o horário não são campos de texto: é a tela que
                  // avisa o formulário de que mudaram.
                  onChanged: () => setState(() {}),
                ),
                if (hasQuotes) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Mudar o tipo, a data ou o número de convidados descarta '
                    'os valores que os fornecedores já informaram: eles '
                    'valiam para o evento como estava.',
                    style: context.text.caption.copyWith(
                      color: context.colors.warning,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: isEditing ? 'Salvar' : 'Criar festa',
                  onPressed: _submit,
                  isLoading: isBusy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
