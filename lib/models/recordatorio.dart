import 'package:flutter/material.dart';

enum TipoRecordatorio { cita, medicamento, control }

extension TipoRecordatorioInfo on TipoRecordatorio {
  String get nombre {
    switch (this) {
      case TipoRecordatorio.cita:
        return 'Cita médica';
      case TipoRecordatorio.medicamento:
        return 'Medicamento';
      case TipoRecordatorio.control:
        return 'Control';
    }
  }

  IconData get icono {
    switch (this) {
      case TipoRecordatorio.cita:
        return Icons.event;
      case TipoRecordatorio.medicamento:
        return Icons.medication;
      case TipoRecordatorio.control:
        return Icons.monitor_heart;
    }
  }
}

/// Recordatorio del usuario (tabla `recordatorios`).
class Recordatorio {
  final String? id; // null cuando aún no se guardó
  final String titulo;
  final String descripcion;
  final TipoRecordatorio tipo;
  final DateTime fechaHora;
  final String? centroId;
  final String? centroNombre;

  const Recordatorio({
    this.id,
    required this.titulo,
    this.descripcion = '',
    this.tipo = TipoRecordatorio.cita,
    required this.fechaHora,
    this.centroId,
    this.centroNombre,
  });

  factory Recordatorio.desdeMapa(Map<String, dynamic> m) {
    final centro = m['centros_salud'] as Map<String, dynamic>?;
    return Recordatorio(
      id: m['id'] as String,
      titulo: m['titulo'] as String,
      descripcion: m['descripcion'] as String? ?? '',
      tipo: TipoRecordatorio.values.byName(m['tipo'] as String),
      fechaHora: DateTime.parse(m['fecha_hora'] as String).toLocal(),
      centroId: m['centro_id'] as String?,
      centroNombre: centro?['nombre'] as String?,
    );
  }

  Map<String, dynamic> aMapa() => {
        'titulo': titulo.trim(),
        'descripcion': descripcion.trim(),
        'tipo': tipo.name,
        'fecha_hora': fechaHora.toUtc().toIso8601String(),
        'centro_id': centroId,
      };

  bool get vencido => fechaHora.isBefore(DateTime.now());
}
