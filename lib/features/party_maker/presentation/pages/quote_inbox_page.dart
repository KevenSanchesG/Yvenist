import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/party_maker/domain/entities/quote_request.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/repositories/quote_inbox_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/quote_inbox_controller.dart';
import 'package:yvenist/features/party_maker/presentation/party_presentation.dart';
import 'package:yvenist/features/party_maker/presentation/widgets/event_type_name.dart';

/// Os pedidos de orçamento que a conta recebeu como fornecedora.
///
/// Cada pedido é um item de uma festa: o fornecedor vê o evento e o que o
/// cliente configurou, e responde com o valor, com um pedido de alteração ou
/// dizendo que não pode atender. Não vê o nome da festa nem de quem pediu.
class QuoteInboxPage extends StatelessWidget {
  const QuoteInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          QuoteInboxController(context.read<QuoteInboxRepository>())..load(),
      child: const _QuoteInboxView(),
    );
  }
}

class _QuoteInboxView extends StatelessWidget {
  const _QuoteInboxView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuoteInboxController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de orçamento')),
      body: switch (controller.state) {
        LoadInProgress() => const LoadingView(label: 'Carregando os pedidos'),
        LoadFailure(:final failure) => ErrorStateView(
          message: failure.message,
          onRetry: controller.load,
        ),
        LoadSuccess(:final value) when value.isEmpty => const EmptyStateView(
          icon: Icons.request_quote_outlined,
          title: 'Nenhum pedido de orçamento',
          message:
              'Quando um cliente pedir o orçamento de um anúncio seu, o '
              'pedido aparece aqui.',
        ),
        LoadSuccess(:final value) => RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: context.withSystemBottomInset(const EdgeInsets.all(16)),
            children: [
              for (final event in _byEvent(value)) ...[
                _EventHeader(request: event.first),
                for (final request in event) ...[
                  _RequestCard(request: request, isBusy: controller.isBusy),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      },
    );
  }

  /// Os pedidos agrupados por evento, na ordem em que chegaram: os itens da
  /// mesma festa ficam juntos, porque são para o mesmo dia.
  static Iterable<List<QuoteRequest>> _byEvent(List<QuoteRequest> requests) {
    final events = <String, List<QuoteRequest>>{};
    for (final request in requests) {
      events.putIfAbsent(request.partyId, () => []).add(request);
    }
    return events.values;
  }
}

/// O evento a que os pedidos se referem: tipo, data, convidados e em que pé o
/// cliente está.
class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.request});

  final QuoteRequest request;

  /// O que o cliente fez com o pedido, quando isso muda o que o fornecedor
  /// pode fazer.
  String? get _situation => switch (request.partyStatus) {
    PartyStatus.confirmed => 'O cliente aceitou o orçamento.',
    PartyStatus.paid => 'O cliente aceitou o orçamento.',
    PartyStatus.cancelled => 'O cliente cancelou a festa.',
    _ =>
      request.round > 1
          ? 'O cliente alterou a festa e pediu de novo '
                '(${request.round}ª rodada).'
          : null,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final date = request.eventDate;
    final guests = request.guestCount;
    final eventType = request.eventType;
    final situation = _situation;
    final when = [
      if (date != null) formatEventDate(date),
      if (guests != null) guestsLabel(guests),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eventType != null)
            EventTypeName(
              slug: eventType,
              builder: (_, name) => Semantics(
                header: true,
                child: Text(name, style: text.cardTitle),
              ),
            ),
          if (when.isNotEmpty)
            Text(when, style: text.body.copyWith(fontWeight: FontWeight.w600)),
          if (situation != null)
            Text(
              situation,
              style: text.caption.copyWith(
                color: request.partyStatus == PartyStatus.cancelled
                    ? colors.danger
                    : colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Um pedido: o item, o que o cliente informou, o que o fornecedor respondeu
/// e as respostas possíveis.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.isBusy});

  final QuoteRequest request;
  final bool isBusy;

  String? get _relation {
    final parent = request.parentName;
    if (parent == null) return null;
    return switch (request.relation) {
      ItemRelationKind.linked => 'Serviço de $parent',
      ItemRelationKind.required => 'Obrigatório com $parent',
      // Para o fornecedor, quem indicou o anúncio dele não muda o pedido.
      ItemRelationKind.recommended || ItemRelationKind.independent => null,
    };
  }

  String get _answer {
    final quote = request.quote;
    return switch (quote.status) {
      QuoteStatus.none => 'O cliente retirou este pedido',
      QuoteStatus.pending => 'Aguardando a sua resposta',
      QuoteStatus.quoted => 'Você informou ${amountLabel(quote.amount)}',
      QuoteStatus.changesRequested => 'Você pediu uma alteração',
      QuoteStatus.declined => 'Você recusou este pedido',
    };
  }

  Future<void> _respond(
    BuildContext context,
    Widget Function(BuildContext) dialog,
    String done,
  ) async {
    final controller = context.read<QuoteInboxController>();
    final messenger = ScaffoldMessenger.of(context);

    final response = await showDialog<VendorResponse>(
      context: context,
      builder: dialog,
    );
    if (response == null) return;

    final sent = await controller.respond(request.itemId, response);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? done
                : controller.error ?? 'Não foi possível enviar a resposta.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final quote = request.quote;
    final relation = _relation;
    final summary = configurationSummary(
      spec: request.spec,
      configuration: request.configuration,
      quantity: request.quantity,
    );
    final notes = request.configuration[ItemConfiguration.notesKey];
    final message = quote.message;
    final canAct = request.canRespond && !isBusy;
    final name = request.name;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: text.cardTitle),
          if (relation != null) Text(relation, style: text.caption),
          const SizedBox(height: 6),
          // Uma informação por linha: é o que o fornecedor precisa ler para
          // dar o preço.
          for (final piece in summary) Text(piece, style: text.body),
          if (notes is String) Text('Observações: $notes', style: text.body),
          const SizedBox(height: 6),
          Text(
            [
              'Estimativa vista pelo cliente: ${amountLabel(request.estimate)}',
              if (pricingBasis(request.pricing) case final basis?) '($basis)',
            ].join(' '),
            style: text.caption,
          ),
          const Divider(height: 20),
          Text(
            _answer,
            style: text.body.copyWith(
              fontWeight: FontWeight.w700,
              color: quote.status.colorIn(colors),
            ),
          ),
          if (message != null) Text('"$message"', style: text.caption),
          const SizedBox(height: 8),
          if (request.canRespond)
            // As três respostas possíveis. O que não cabe na linha desce para
            // a de baixo, em vez de estourar a largura do cartão.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: canAct
                        ? () => _respond(
                            context,
                            (_) => _ExplanationDialog(
                              title: 'Recusar o pedido de $name?',
                              label: 'Por que você não pode atender',
                              action: 'Recusar pedido',
                              build: VendorResponse.decline,
                            ),
                            'Pedido recusado. O cliente vê o motivo na festa '
                            'dele.',
                          )
                        : null,
                    child: const Text('Recusar'),
                  ),
                  TextButton(
                    onPressed: canAct
                        ? () => _respond(
                            context,
                            (_) => _ExplanationDialog(
                              title: 'Pedir uma alteração em $name',
                              label: 'O que o cliente precisa mudar',
                              action: 'Pedir alteração',
                              build: VendorResponse.requestChanges,
                            ),
                            'Alteração pedida. O cliente vê o recado na festa '
                            'dele.',
                          )
                        : null,
                    child: const Text('Pedir alteração'),
                  ),
                  // A resposta mais comum, em destaque.
                  OutlinedButton(
                    onPressed: canAct
                        ? () => _respond(
                            context,
                            (_) => _AmountDialog(request: request),
                            'Valor enviado. O cliente vê o orçamento na festa '
                            'dele.',
                          )
                        : null,
                    child: Text(
                      quote.isQuoted ? 'Corrigir valor' : 'Informar valor',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Pede o valor do orçamento. Fecha devolvendo a resposta pronta para enviar.
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.request});

  final QuoteRequest request;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _message;

  @override
  void initState() {
    super.initState();
    final quote = widget.request.quote;
    final current = quote.isQuoted ? quote.amount : null;
    _amount = TextEditingController(
      text: current == null
          ? ''
          : formatBrl(current.cents).replaceFirst(r'R$ ', ''),
    );
    _message = TextEditingController(
      text: quote.isQuoted ? quote.message ?? '' : '',
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _message.dispose();
    super.dispose();
  }

  static String? _validateAmount(String? value) {
    final cents = parseBrlToCents(value ?? '');
    if (cents == null) return 'Informe o valor, por exemplo 1500 ou 1.500,00.';
    if (cents > VendorResponse.maxAmountCents) {
      return 'O valor máximo é ${formatBrl(VendorResponse.maxAmountCents)}.';
    }
    return null;
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final message = _message.text.trim();
    Navigator.pop(
      context,
      VendorResponse.quote(
        Money.fromCents(
          parseBrlToCents(_amount.text)!,
          currency: widget.request.pricing.currency,
        ),
        message: message.isEmpty ? null : message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Valor de ${widget.request.name}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                ],
                validator: _validateAmount,
                decoration: const InputDecoration(
                  labelText: 'Valor do orçamento',
                  prefixText: r'R$ ',
                  helperText: 'O total para este item, como foi pedido.',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _message,
                maxLength: VendorResponse.maxMessageLength,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Mensagem para o cliente (opcional)',
                  hintText: 'Ex.: o que está incluído, condições',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Enviar valor')),
      ],
    );
  }
}

/// Pede a explicação que acompanha um pedido de alteração ou uma recusa. O
/// cliente só consegue agir se souber o motivo, então ela é obrigatória.
class _ExplanationDialog extends StatefulWidget {
  const _ExplanationDialog({
    required this.title,
    required this.label,
    required this.action,
    required this.build,
  });

  final String title;
  final String label;
  final String action;

  /// Monta a resposta a partir do que o fornecedor escreveu.
  final VendorResponse Function(String message) build;

  @override
  State<_ExplanationDialog> createState() => _ExplanationDialogState();
}

class _ExplanationDialogState extends State<_ExplanationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, widget.build(_message.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: TextFormField(
            controller: _message,
            autofocus: true,
            maxLength: VendorResponse.maxMessageLength,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) =>
                (value?.trim().length ?? 0) <
                    VendorResponse.minExplanationLength
                ? 'Explique o motivo para o cliente.'
                : null,
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: 'O cliente lê esta mensagem.',
              alignLabelWithHint: true,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirm, child: Text(widget.action)),
      ],
    );
  }
}
