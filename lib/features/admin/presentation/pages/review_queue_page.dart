import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/utils/brazilian_documents.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/admin/domain/review_models.dart';
import 'package:yvenist/features/admin/domain/review_repository.dart';
import 'package:yvenist/features/admin/presentation/controllers/review_queue_controller.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:yvenist/features/client/shared/catalog_presentation.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

/// O preço de um anúncio em análise, com o valor mínimo quando há.
String _priceLine(ListingReview listing) {
  final cents = listing.priceFromCents;
  // O valor fixo é o preço inicial, e aqui aparece com os centavos: quem
  // analisa confere o número que o fornecedor digitou.
  final price = listing.pricingModel == PricingModel.fixed && cents != null
      ? 'A partir de ${formatBrl(cents)}'
      : describePricing(listing.pricingModel, cents);
  final minimum = listing.minimumPriceCents;
  return minimum == null ? price : '$price · mínimo de ${formatBrl(minimum)}';
}

/// Um serviço próprio em uma linha: "Buffet da casa (R$ 45 por pessoa)".
String _offerLine(ListingOffer offer) {
  final price = describePricing(offer.pricingModel, offer.priceCents);
  final required = offer.isRequired ? ', obrigatório' : '';
  return '${offer.name} ($price$required)';
}

/// Fila de análise: cadastros de fornecedor e anúncios esperando uma decisão.
///
/// Só é oferecida a contas de administração; para qualquer outra o servidor
/// recusa as chamadas, e a tela mostra o erro.
class ReviewQueuePage extends StatelessWidget {
  const ReviewQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ReviewQueueController(
        reviews: context.read<ReviewRepository>(),
        catalog: context.read<CatalogRepository>(),
      )..load(),
      child: const _ReviewQueueView(),
    );
  }
}

class _ReviewQueueView extends StatelessWidget {
  const _ReviewQueueView();

  // As decisões são conduzidas daqui, e não de cada cartão: o cartão sai da
  // tela quando a fila recarrega, e o aviso do resultado precisa de um
  // contexto que continue existindo.

  Future<void> _approveVendor(
    BuildContext context,
    VendorReview vendor,
    List<ListingReview> listings,
  ) async {
    final controller = context.read<ReviewQueueController>();
    final publish = await showDialog<bool>(
      context: context,
      builder: (_) => _ApproveVendorDialog(vendor: vendor, listings: listings),
    );
    if (publish == null) return;

    final failure = await controller.approveVendor(
      vendor,
      publishListings: publish,
    );
    if (!context.mounted) return;
    showAppSnackBar(context, failure?.message ?? 'Cadastro aprovado.');
  }

  Future<void> _rejectVendor(
    BuildContext context,
    VendorReview vendor,
    List<ListingReview> listings,
  ) async {
    final controller = context.read<ReviewQueueController>();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(
        title: 'Recusar cadastro?',
        note: listings.isEmpty
            ? null
            : 'Os anúncios em análise deste cadastro também são recusados, '
                  'com o mesmo motivo.',
      ),
    );
    if (reason == null) return;

    final failure = await controller.rejectVendor(vendor, reason);
    if (!context.mounted) return;
    showAppSnackBar(context, failure?.message ?? 'Cadastro recusado.');
  }

  Future<void> _approveListing(
    BuildContext context,
    ListingReview listing,
  ) async {
    final controller = context.read<ReviewQueueController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publicar anúncio?'),
        content: Text(
          '"${listing.title}" passa a aparecer para todos no catálogo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final failure = await controller.approveListing(listing);
    if (!context.mounted) return;
    showAppSnackBar(context, failure?.message ?? 'Anúncio publicado.');
  }

  Future<void> _rejectListing(
    BuildContext context,
    ListingReview listing,
  ) async {
    final controller = context.read<ReviewQueueController>();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(title: 'Recusar anúncio?'),
    );
    if (reason == null) return;

    final failure = await controller.rejectListing(listing, reason);
    if (!context.mounted) return;
    showAppSnackBar(context, failure?.message ?? 'Anúncio recusado.');
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReviewQueueController>();
    final queue = controller.state.valueOrNull;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.colors.backgroundMuted,
        appBar: AppBar(
          title: const Text('Fila de análise'),
          bottom: TabBar(
            tabs: [
              Tab(text: _tabLabel('Fornecedores', queue?.vendors.length)),
              Tab(text: _tabLabel('Anúncios', queue?.listings.length)),
            ],
          ),
        ),
        body: switch (controller.state) {
          LoadInProgress() => const LoadingView(),
          LoadFailure(:final failure) => ErrorStateView(
            message: failure.message,
            onRetry: controller.load,
          ),
          LoadSuccess(value: final queue) => TabBarView(
            children: [
              _QueueList(
                emptyTitle: 'Nenhum cadastro aguardando',
                emptyMessage:
                    'Quando alguém pedir para anunciar, o cadastro aparece '
                    'aqui.',
                onRefresh: controller.load,
                children: [
                  for (final vendor in queue.vendors)
                    _VendorCard(
                      vendor: vendor,
                      listings: queue.listingsOf(vendor.id),
                      isDeciding: controller.isDeciding(vendor.id),
                      onApprove: () => _approveVendor(
                        context,
                        vendor,
                        queue.listingsOf(vendor.id),
                      ),
                      onReject: () => _rejectVendor(
                        context,
                        vendor,
                        queue.listingsOf(vendor.id),
                      ),
                    ),
                ],
              ),
              _QueueList(
                emptyTitle: 'Nenhum anúncio aguardando',
                emptyMessage:
                    'Os anúncios enviados pelos fornecedores aparecem aqui.',
                onRefresh: controller.load,
                children: [
                  for (final listing in queue.listings)
                    _ListingCard(
                      listing: listing,
                      categoryName: controller.categoryName(
                        listing.categorySlug,
                      ),
                      eventTypeNames: [
                        for (final slug in listing.eventTypes)
                          controller.eventTypeName(slug),
                      ],
                      isDeciding: controller.isDeciding(listing.id),
                      onApprove: () => _approveListing(context, listing),
                      onReject: () => _rejectListing(context, listing),
                    ),
                ],
              ),
            ],
          ),
        },
      ),
    );
  }

  static String _tabLabel(String name, int? count) {
    return count == null ? name : '$name ($count)';
  }
}

/// Uma das duas filas: os cartões, ou a explicação de que está vazia.
class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRefresh,
    required this.children,
  });

  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return EmptyStateView(
        icon: Icons.inbox_outlined,
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: 'Atualizar',
        onAction: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: context.withSystemBottomInset(const EdgeInsets.all(16)),
        itemCount: children.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              'Do mais antigo para o mais novo, até 50 por vez.',
              style: context.text.caption,
            );
          }
          return children[index - 1];
        },
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.listings,
    required this.isDeciding,
    required this.onApprove,
    required this.onReject,
  });

  final VendorReview vendor;
  final List<ListingReview> listings;
  final bool isDeciding;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isCompany = vendor.personType == PersonType.company;
    final titles = [for (final listing in listings) listing.title];

    return _QueueCard(
      title: vendor.legalName,
      children: [
        Text(
          '${isCompany ? 'Pessoa jurídica' : 'Pessoa física'} · '
          '${isCompany ? 'CNPJ' : 'CPF'} ${formatDocument(vendor.document)}',
          style: context.text.body,
        ),
        const SizedBox(height: 2),
        Text(
          'Cadastro de ${_dateFormat.format(vendor.createdAt.toLocal())}',
          style: context.text.caption,
        ),
        const SizedBox(height: 8),
        Text(
          titles.isEmpty
              ? 'Nenhum anúncio em análise.'
              : 'Em análise com este cadastro: ${titles.join(', ')}.',
          style: context.text.caption,
        ),
        const SizedBox(height: 12),
        _DecisionButtons(
          approveLabel: 'Aprovar',
          isDeciding: isDeciding,
          onApprove: onApprove,
          onReject: onReject,
        ),
      ],
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.categoryName,
    required this.eventTypeNames,
    required this.isDeciding,
    required this.onApprove,
    required this.onReject,
  });

  final ListingReview listing;
  final String categoryName;
  final List<String> eventTypeNames;
  final bool isDeciding;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final amenities = [
      for (final slug in listing.amenities) amenityLabel(slug),
    ];

    return _QueueCard(
      title: listing.title,
      children: [
        Text('$categoryName · ${listing.location}', style: context.text.body),
        const SizedBox(height: 2),
        Text(_priceLine(listing), style: context.text.body),
        const SizedBox(height: 2),
        Text(
          'Fornecedor: ${listing.vendorName} · enviado em '
          '${_dateFormat.format(listing.createdAt.toLocal())}',
          style: context.text.caption,
        ),
        ExpansionTile(
          title: Text('Ver detalhes', style: context.text.body),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.centerLeft,
          // Sem as linhas que o Material põe acima e abaixo ao abrir.
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            _Detail(label: 'Descrição', value: listing.description),
            if (listing.capacity != null)
              _Detail(
                label: 'Capacidade',
                value: '${listing.capacity} pessoas',
              ),
            if (listing.areaM2 != null)
              _Detail(label: 'Área', value: '${listing.areaM2} m²'),
            _Detail(
              label: 'Eventos',
              value: eventTypeNames.isEmpty
                  ? 'Não informados'
                  : eventTypeNames.join(', '),
            ),
            _Detail(
              label: 'Estrutura',
              value: amenities.isEmpty ? 'Não informada' : amenities.join(', '),
            ),
            _Detail(
              label: 'Cancelamento',
              value:
                  '${listing.cancellationPolicy.label}. '
                  '${listing.cancellationPolicy.summary}',
            ),
            // Quem publica o anúncio publica também o que ele oferece junto.
            _Detail(
              label: 'Serviços próprios',
              value: listing.offers.isEmpty
                  ? 'Nenhum'
                  : listing.offers.map(_offerLine).join('; '),
            ),
          ],
        ),
        if (!listing.canBePublished) ...[
          Text(
            'O cadastro deste fornecedor ainda não foi aprovado. Aprove o '
            'cadastro na aba Fornecedores para poder publicar o anúncio.',
            style: context.text.caption.copyWith(color: context.colors.warning),
          ),
          const SizedBox(height: 12),
        ],
        _DecisionButtons(
          approveLabel: 'Publicar',
          isDeciding: isDeciding,
          onApprove: listing.canBePublished ? onApprove : null,
          onReject: onReject,
        ),
      ],
    );
  }
}

/// Cartão branco de um item da fila, com o nome em destaque.
class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: context.text.cardTitle),
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          style: context.text.body,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

/// Recusar e aprovar. Sem [onApprove] a aprovação não é possível agora.
class _DecisionButtons extends StatelessWidget {
  const _DecisionButtons({
    required this.approveLabel,
    required this.isDeciding,
    required this.onApprove,
    required this.onReject,
  });

  final String approveLabel;
  final bool isDeciding;
  final VoidCallback? onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    // Com letras grandes os dois botões não cabem lado a lado: o OverflowBar
    // passa a empilhar em vez de cortar.
    return OverflowBar(
      alignment: MainAxisAlignment.end,
      spacing: 12,
      overflowSpacing: 8,
      overflowAlignment: OverflowBarAlignment.end,
      children: [
        OutlinedButton(
          onPressed: isDeciding ? null : onReject,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.danger,
          ),
          child: const Text('Recusar'),
        ),
        FilledButton(
          onPressed: isDeciding ? null : onApprove,
          child: isDeciding
              ? Semantics(
                  label: 'Enviando',
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : Text(approveLabel),
        ),
      ],
    );
  }
}

/// Confirma a aprovação de um cadastro. Fecha com `true` se os anúncios em
/// análise devem ser publicados junto, `false` se não, e `null` se desistiu.
class _ApproveVendorDialog extends StatefulWidget {
  const _ApproveVendorDialog({required this.vendor, required this.listings});

  final VendorReview vendor;
  final List<ListingReview> listings;

  @override
  State<_ApproveVendorDialog> createState() => _ApproveVendorDialogState();
}

class _ApproveVendorDialogState extends State<_ApproveVendorDialog> {
  bool _publish = true;

  @override
  Widget build(BuildContext context) {
    final listings = widget.listings;

    return AlertDialog(
      title: const Text('Aprovar cadastro?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.vendor.legalName} passa a poder anunciar no Yvenist.',
            ),
            if (listings.isNotEmpty) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _publish,
                onChanged: (value) => setState(() => _publish = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  listings.length == 1
                      ? 'Publicar também o anúncio "${listings.single.title}"'
                      : 'Publicar também os ${listings.length} anúncios em '
                            'análise',
                  style: context.text.body,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          // Só publica junto o que apareceu nesta tela: sem anúncios à vista,
          // nada é publicado sem ter sido olhado.
          onPressed: () =>
              Navigator.pop(context, listings.isNotEmpty && _publish),
          child: const Text('Aprovar'),
        ),
      ],
    );
  }
}

/// Pede o motivo de uma recusa. Fecha com o texto, ou `null` se desistiu.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.title, this.note});

  final String title;

  /// Consequência da recusa que quem decide precisa saber antes.
  final String? note;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  static const int _minLength = 5;
  static const int _maxLength = 500;

  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.note != null) ...[
                Text(widget.note!),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _reason,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                maxLength: _maxLength,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => (value ?? '').trim().length < _minLength
                    ? 'Explique o motivo da recusa.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Motivo da recusa',
                  helperText: 'O fornecedor vai ler este texto.',
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
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(foregroundColor: context.colors.danger),
          child: const Text('Recusar'),
        ),
      ],
    );
  }
}
