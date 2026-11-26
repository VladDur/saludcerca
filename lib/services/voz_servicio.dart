import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Fallas del reconocimiento de voz.
enum TipoErrorVoz {
  permisoDenegado, // el usuario no dio permiso de micrófono o de voz
  noDisponible, // el teléfono no tiene reconocimiento de voz
  sinConexion, // el reconocedor necesita internet y no hay
  noEntendio, // no se escuchó nada o no se reconoció
  otro,
}

class VozException implements Exception {
  final TipoErrorVoz tipo;
  final String? detalle;
  const VozException(this.tipo, {this.detalle});

  String get mensaje => switch (tipo) {
        TipoErrorVoz.permisoDenegado =>
          'Para dictar, permite el uso del micrófono y del reconocimiento '
              'de voz en los ajustes del teléfono.',
        TipoErrorVoz.noDisponible =>
          'Este teléfono no tiene reconocimiento de voz. '
              'Escribe el título con el teclado.',
        TipoErrorVoz.sinConexion =>
          'Sin conexión a internet: el dictado por voz no está disponible.',
        TipoErrorVoz.noEntendio =>
          'No te escuchamos bien. Toca el micrófono y habla otra vez, '
              'cerca del teléfono.',
        TipoErrorVoz.otro =>
          'No se pudo usar el dictado por voz. Intenta otra vez.',
      };

  /// Traduce los códigos de error de speech_to_text (Android e iOS).
  static VozException desdeCodigo(String codigo) {
    final c = codigo.toLowerCase();
    if (c.contains('permission')) {
      return VozException(TipoErrorVoz.permisoDenegado, detalle: codigo);
    }
    if (c.contains('network') || c.contains('server')) {
      return VozException(TipoErrorVoz.sinConexion, detalle: codigo);
    }
    if (c.contains('no_match') ||
        c.contains('speech_timeout') ||
        c.contains('nomatch') ||
        c.contains('retry')) {
      return VozException(TipoErrorVoz.noEntendio, detalle: codigo);
    }
    return VozException(TipoErrorVoz.otro, detalle: codigo);
  }

  @override
  String toString() => 'VozException($tipo, $detalle)';
}

/// Contrato del dictado por voz (las pruebas usan uno falso).
abstract class VozServicio {
  /// Escucha una frase en español. Llama a [alParcial] con lo que va
  /// reconociendo y devuelve el texto final. Lanza [VozException].
  Future<String> dictar({void Function(String parcial)? alParcial});

  /// Termina de escuchar antes de tiempo (el texto dicho hasta ahí se
  /// devuelve como final).
  Future<void> detener();
}

/// Dictado con el reconocedor del sistema (Google en Android, Apple Speech
/// en iOS) mediante el paquete speech_to_text.
class SttVozServicio implements VozServicio {
  final SpeechToText _stt;
  bool _listo = false;
  String? _idioma;
  Completer<String>? _pendiente;
  String _ultimo = '';

  SttVozServicio({SpeechToText? stt}) : _stt = stt ?? SpeechToText();

  Future<void> _preparar() async {
    if (_listo) return;
    final bool ok;
    try {
      // initialize() pide los permisos de micrófono y de voz la primera vez.
      ok = await _stt.initialize(
        onError: _alError,
        onStatus: _alEstado,
        finalTimeout: const Duration(seconds: 2),
      );
    } catch (e) {
      throw VozException(TipoErrorVoz.noDisponible, detalle: '$e');
    }
    if (!ok) {
      // En iOS y Android, initialize devuelve false si se negó el permiso
      // o si el teléfono no tiene el servicio.
      final permiso = await _stt.hasPermission;
      throw VozException(
          permiso ? TipoErrorVoz.noDisponible : TipoErrorVoz.permisoDenegado);
    }
    _idioma = await _idiomaEspanol();
    _listo = true;
  }

  /// Prefiere español de Bolivia; si no está, cualquier español.
  Future<String?> _idiomaEspanol() async {
    final idiomas = await _stt.locales();
    String norm(String id) => id.replaceAll('-', '_').toLowerCase();
    for (final pref in const ['es_bo', 'es_419', 'es_us', 'es_mx', 'es_es']) {
      for (final l in idiomas) {
        if (norm(l.localeId) == pref) return l.localeId;
      }
    }
    for (final l in idiomas) {
      if (norm(l.localeId).startsWith('es')) return l.localeId;
    }
    return 'es_ES';
  }

  @override
  Future<String> dictar({void Function(String parcial)? alParcial}) async {
    await _preparar();
    if (_stt.isListening) await _stt.stop();
    final pendiente = _pendiente = Completer<String>();
    _ultimo = '';
    debugPrint('[VOZ] escuchando en $_idioma');
    await _stt.listen(
      onResult: (r) {
        _ultimo = r.recognizedWords;
        alParcial?.call(_ultimo);
        if (r.finalResult) _terminar();
      },
      listenOptions: SpeechListenOptions(
        localeId: _idioma,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
    return pendiente.future;
  }

  void _terminar() {
    final p = _pendiente;
    if (p == null || p.isCompleted) return;
    final texto = _ultimo.trim();
    texto.isEmpty
        ? p.completeError(const VozException(TipoErrorVoz.noEntendio))
        : p.complete(texto);
  }

  void _alError(SpeechRecognitionError e) {
    debugPrint('[VOZ] error ${e.errorMsg} (permanente: ${e.permanent})');
    final p = _pendiente;
    if (p == null || p.isCompleted) return;
    // Si ya se reconoció algo, nos quedamos con eso.
    if (_ultimo.trim().isNotEmpty) return _terminar();
    p.completeError(VozException.desdeCodigo(e.errorMsg));
  }

  void _alEstado(String estado) {
    debugPrint('[VOZ] estado $estado');
    // "done" llega al terminar de escuchar, haya o no resultado final.
    if (estado == SpeechToText.doneStatus) {
      Future.delayed(const Duration(milliseconds: 300), _terminar);
    }
  }

  @override
  Future<void> detener() async {
    if (_stt.isListening) await _stt.stop();
  }
}

/// Deja el texto dictado listo para usarlo como título: sin espacios de más,
/// con la primera letra en mayúscula y sin pasar de [maximo] caracteres.
String textoDictadoComoTitulo(String texto, {int maximo = 60}) {
  var t = texto.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  if (t.isEmpty) return t;
  t = t[0].toUpperCase() + t.substring(1);
  return t.length > maximo ? t.substring(0, maximo).trimRight() : t;
}
