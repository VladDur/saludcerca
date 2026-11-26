import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/centro_salud.dart';

/// De dónde salió la ubicación usada para calcular distancias.
enum OrigenUbicacion { gps, referencia }

class ResultadoUbicacion {
  final Ubicacion ubicacion;
  final OrigenUbicacion origen;

  /// Por qué no se usó el GPS (null si se usó).
  final String? motivo;

  const ResultadoUbicacion.gps(this.ubicacion)
      : origen = OrigenUbicacion.gps,
        motivo = null;

  const ResultadoUbicacion.referencia(this.motivo)
      : ubicacion = Ubicacion.referencia,
        origen = OrigenUbicacion.referencia;

  bool get esGps => origen == OrigenUbicacion.gps;
}

/// HU-13: ubicación del teléfono. Si no se puede usar el GPS, la app
/// sigue funcionando con la referencia (Plaza Murillo) y explica el motivo.
abstract class UbicacionServicio {
  Future<ResultadoUbicacion> obtener({bool forzar = false});

  /// Último resultado conocido, sin esperar al GPS (Plaza Murillo si aún
  /// no se consultó).
  ResultadoUbicacion get ultimaConocida;
}

const sinConsultar = ResultadoUbicacion.referencia('Buscando tu ubicación…');

/// Distancia máxima a Plaza Murillo para considerar que el usuario está en
/// La Paz o El Alto. Más lejos, las distancias no tendrían sentido.
const radioCoberturaKm = 40.0;

/// Decide qué ubicación usar a partir de la posición del GPS.
ResultadoUbicacion evaluarPosicion(Ubicacion gps) {
  if (Ubicacion.referencia.distanciaKm(gps) > radioCoberturaKm) {
    return const ResultadoUbicacion.referencia(
        'Estás fuera de La Paz y El Alto');
  }
  return ResultadoUbicacion.gps(gps);
}

class GpsUbicacionServicio implements UbicacionServicio {
  final Duration vigencia;
  ResultadoUbicacion? _ultimo;
  DateTime? _cuando;
  Future<ResultadoUbicacion>? _enCurso;

  GpsUbicacionServicio({this.vigencia = const Duration(minutes: 2)});

  @override
  ResultadoUbicacion get ultimaConocida => _ultimo ?? sinConsultar;

  @override
  Future<ResultadoUbicacion> obtener({bool forzar = false}) {
    final u = _ultimo;
    if (!forzar &&
        u != null &&
        DateTime.now().difference(_cuando!) < vigencia) {
      return Future.value(u);
    }
    // Si dos pantallas piden la ubicación a la vez, se comparte la consulta.
    return _enCurso ??= _leer().whenComplete(() => _enCurso = null);
  }

  Future<ResultadoUbicacion> _leer() async {
    final r = await _consultarGps();
    _ultimo = r;
    _cuando = DateTime.now();
    return r;
  }

  Future<ResultadoUbicacion> _consultarGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const ResultadoUbicacion.referencia('El GPS está apagado');
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied) {
        return const ResultadoUbicacion.referencia(
            'No diste permiso de ubicación');
      }
      if (permiso == LocationPermission.deniedForever) {
        return const ResultadoUbicacion.referencia(
            'El permiso de ubicación está bloqueado en Ajustes');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return evaluarPosicion(Ubicacion(p.latitude, p.longitude));
    } on TimeoutException {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null) {
        return evaluarPosicion(Ubicacion(ultima.latitude, ultima.longitude));
      }
      return const ResultadoUbicacion.referencia(
          'El GPS tardó demasiado en responder');
    } catch (_) {
      return const ResultadoUbicacion.referencia(
          'No pudimos leer tu ubicación');
    }
  }
}

