import 'package:flutter/material.dart';

import '../core/validadores.dart';

/// Pregunta qué medicamento se busca. Devuelve null si se cancela.
Future<String?> pedirMedicamento(BuildContext context) => showDialog<String>(
    context: context, builder: (_) => const _DialogoMedicamento());

class _DialogoMedicamento extends StatefulWidget {
  const _DialogoMedicamento();

  @override
  State<_DialogoMedicamento> createState() => _DialogoMedicamentoState();
}

class _DialogoMedicamentoState extends State<_DialogoMedicamento> {
  final _formulario = GlobalKey<FormState>();
  final _medicamento = TextEditingController();

  @override
  void dispose() {
    _medicamento.dispose();
    super.dispose();
  }

  void _continuar() {
    if (!_formulario.currentState!.validate()) return;
    Navigator.pop(context, _medicamento.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return AlertDialog(
      scrollable: true,
      title: const Text('¿Qué medicamento buscas?'),
      content: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                'Se abrirá WhatsApp con el mensaje escrito. '
                'Revísalo y toca Enviar.',
                style: textos.bodyLarge),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('consulta_medicamento'),
              controller: _medicamento,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onFieldSubmitted: (_) => _continuar(),
              decoration: const InputDecoration(
                labelText: 'Medicamento',
                hintText: 'Paracetamol 500 mg',
              ),
              validator: Validadores.medicamento,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            key: const Key('consulta_abrir'),
            onPressed: _continuar,
            child: const Text('Abrir WhatsApp')),
      ],
    );
  }
}
