import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_item_catalog.dart';

/// Mostra o nome de um tipo de evento a partir do `slug` que a festa guarda.
///
/// O nome vem do catálogo. Enquanto ele não chega, ou se o tipo não existe
/// mais, nada aparece: um `slug` não é texto para a pessoa ler.
class EventTypeName extends StatefulWidget {
  const EventTypeName({super.key, required this.slug, required this.builder});

  final String slug;

  /// Monta o que aparece, com o nome do tipo.
  final Widget Function(BuildContext context, String name) builder;

  @override
  State<EventTypeName> createState() => _EventTypeNameState();
}

class _EventTypeNameState extends State<EventTypeName> {
  List<EventTypeOption> _types = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final types = await context.read<PartyItemCatalog>().eventTypes();
      if (mounted) setState(() => _types = types);
    } catch (_) {
      // Sem o catálogo, a linha do tipo de evento simplesmente não aparece.
    }
  }

  @override
  Widget build(BuildContext context) {
    for (final type in _types) {
      if (type.slug == widget.slug) return widget.builder(context, type.name);
    }
    return const SizedBox.shrink();
  }
}
