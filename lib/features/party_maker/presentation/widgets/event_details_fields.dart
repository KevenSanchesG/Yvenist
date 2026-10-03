import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yvenist/core/widgets/form_widgets.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_item_catalog.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/presentation/party_presentation.dart';

/// O que a pessoa preencheu sobre o evento, antes de virar o dado da festa.
///
/// Quem monta o formulário é dono deste objeto (e o descarta); os campos de
/// [EventDetailsFields] só leem e escrevem nele.
class EventDetailsInput {
  EventDetailsInput({String? eventType, DateTime? eventDate, int? guestCount})
    : this._(eventType, eventDate, eventDate?.toLocal(), guestCount);

  EventDetailsInput._(
    this.eventType,
    this._original,
    DateTime? local,
    int? guestCount,
  ) : day = local == null ? null : DateUtils.dateOnly(local),
      time = local == null ? null : TimeOfDay.fromDateTime(local),
      guests = TextEditingController(text: guestCount?.toString() ?? '');

  /// A data que a festa já tinha, exatamente como veio.
  final DateTime? _original;

  String? eventType;
  DateTime? day;
  TimeOfDay? time;
  final TextEditingController guests;

  /// O dia e a hora juntos, ou `null` se a pessoa não informou o dia.
  DateTime? get eventDate {
    final day = this.day;
    if (day == null) return null;
    final picked = DateTime(
      day.year,
      day.month,
      day.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );

    // O formulário só conhece dia, hora e minuto. Se a pessoa não mexeu neles,
    // a data volta como veio (com os segundos, se a festa os tinha): gravar a
    // data arredondada seria mudar o evento sem ninguém ter mudado nada, e
    // mudar o evento descarta os orçamentos recebidos.
    final original = _original;
    if (original != null) {
      final local = original.toLocal();
      final sameMinute =
          DateUtils.isSameDay(local, picked) &&
          local.hour == picked.hour &&
          local.minute == picked.minute;
      if (sameMinute) return original;
    }
    return picked;
  }

  int? get guestCount => int.tryParse(guests.text.trim());

  void dispose() => guests.dispose();
}

/// Os campos do evento: tipo, data, horário e número de convidados.
///
/// São da festa, e não de um item. Aparecem na tela do evento e, quando um
/// item precisa deles para entrar (um salão, um buffet por pessoa), dentro da
/// configuração do item, já preenchidos com o que a festa tem.
class EventDetailsFields extends StatefulWidget {
  const EventDetailsFields({
    super.key,
    required this.input,
    required this.eventTypes,
    this.requireDate = false,
    this.requireGuests = false,
    this.guestsOnly = false,
    this.maxGuests,
    this.onChanged,
  });

  final EventDetailsInput input;
  final List<EventTypeOption> eventTypes;

  /// O item que está sendo configurado não entra sem a data.
  final bool requireDate;

  /// O item que está sendo configurado não entra sem o número de convidados.
  final bool requireGuests;

  /// Mostra só o número de convidados: é tudo o que um item cobrado por pessoa
  /// precisa do evento.
  final bool guestsOnly;

  /// Quantas pessoas o espaço comporta, para avisar antes de enviar.
  final int? maxGuests;

  /// Chamado quando qualquer campo muda: quem usa recalcula a estimativa.
  final VoidCallback? onChanged;

  @override
  State<EventDetailsFields> createState() => _EventDetailsFieldsState();
}

class _EventDetailsFieldsState extends State<EventDetailsFields> {
  EventDetailsInput get _input => widget.input;

  void _changed() {
    setState(() {});
    widget.onChanged?.call();
  }

  Future<void> _pickDay() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = _input.day;
    final picked = await showDatePicker(
      context: context,
      // Uma festa não se marca para o passado.
      firstDate: today,
      lastDate: DateTime(today.year + 5, 12, 31),
      // Uma data antiga (de uma festa que já passou) não cabe no calendário:
      // ele abre em hoje.
      initialDate: current != null && !current.isBefore(today)
          ? current
          : today.add(const Duration(days: 30)),
      helpText: 'Data da festa',
    );
    if (picked == null || !mounted) return;
    _input.day = picked;
    _changed();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _input.time ?? const TimeOfDay(hour: 19, minute: 0),
      helpText: 'Horário de início',
    );
    if (picked == null || !mounted) return;
    _input.time = picked;
    _changed();
  }

  String? _validateGuests(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return widget.requireGuests ? 'Informe o número de convidados.' : null;
    }
    final guests = int.tryParse(text);
    if (guests == null || guests < 1) {
      return 'Informe um número maior que zero.';
    }
    if (guests > GuestCount.max) return 'O máximo é ${GuestCount.max}.';
    final max = widget.maxGuests;
    if (max != null && guests > max) {
      return 'O espaço comporta até $max pessoas.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final optional = widget.requireDate ? '' : ' (opcional)';
    final max = widget.maxGuests;
    final day = _input.day;

    final guests = TextFormField(
      controller: _input.guests,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: _validateGuests,
      onChanged: (_) => _changed(),
      decoration: InputDecoration(
        labelText: widget.requireGuests
            ? 'Número de convidados'
            : 'Número de convidados (opcional)',
        helperText: max == null ? null : 'O espaço comporta até $max.',
      ),
    );
    if (widget.guestsOnly) return guests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          // Os tipos podem chegar depois de a tela abrir. O campo só lê o
          // valor inicial ao nascer: com a chave, ele nasce de novo quando a
          // lista chega e mostra o tipo que a festa já tinha.
          key: ValueKey(widget.eventTypes.length),
          initialValue: widget.eventTypes.any((t) => t.slug == _input.eventType)
              ? _input.eventType
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tipo de evento (opcional)',
          ),
          items: [
            const DropdownMenuItem(child: Text('Não informar')),
            for (final type in widget.eventTypes)
              DropdownMenuItem(value: type.slug, child: Text(type.name)),
          ],
          onChanged: (value) {
            _input.eventType = value;
            _changed();
          },
        ),
        const SizedBox(height: 16),
        PickerFormField(
          label: 'Data$optional',
          value: day == null ? '' : formatDay(day),
          icon: Icons.calendar_today_outlined,
          onTap: _pickDay,
          validator: () => widget.requireDate && _input.day == null
              ? 'Informe a data da festa.'
              : null,
        ),
        const SizedBox(height: 16),
        PickerFormField(
          label: 'Horário de início$optional',
          // O formato da hora é o do aparelho (24h ou AM/PM).
          value: _input.time?.format(context) ?? '',
          icon: Icons.schedule,
          onTap: _pickTime,
          // Com o dia marcado, o horário faz parte da data: sem ele o
          // fornecedor não sabe quando chegar.
          validator: () => _input.day != null && _input.time == null
              ? 'Informe o horário de início.'
              : null,
        ),
        const SizedBox(height: 16),
        guests,
      ],
    );
  }
}
