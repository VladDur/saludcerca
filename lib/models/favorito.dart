import 'centro_salud.dart';

/// Centro marcado como favorito por el usuario (tabla `favoritos`).
class Favorito {
  final String id;
  final String centroId;
  final String nota;
  final CentroSalud? centro;

  const Favorito({
    required this.id,
    required this.centroId,
    required this.nota,
    this.centro,
  });

  factory Favorito.desdeMapa(Map<String, dynamic> m, {CentroSalud? centro}) =>
      Favorito(
        id: m['id'] as String,
        centroId: m['centro_id'] as String,
        nota: m['nota'] as String? ?? '',
        centro: centro,
      );
}
