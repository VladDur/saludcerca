import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludcerca/core/errores.dart';
import 'package:saludcerca/core/validadores.dart';
import 'package:saludcerca/data/supabase/supabase_repositorios.dart';
import 'package:saludcerca/models/centro_salud.dart';
import 'package:saludcerca/models/recordatorio.dart';
import 'package:saludcerca/settings/ajustes_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthRetryableFetchException, AuthWeakPasswordException;

void main() {
  group('Validadores de formularios', () {
    test('correo', () {
      expect(Validadores.correo(''), 'Escribe tu correo');
      expect(Validadores.correo('ana@'), 'El correo no es válido');
      expect(Validadores.correo('ana@correo.com'), isNull);
    });
    test('contraseña nueva exige 6 caracteres con letras y números', () {
      expect(Validadores.claveNueva('abc'), 'Mínimo 6 caracteres');
      expect(Validadores.claveNueva('abcdef'), 'Usa letras y números');
      expect(Validadores.claveNueva('abc123'), isNull);
    });
    test('confirmar contraseña', () {
      final v = Validadores.confirmarClave(() => 'abc123');
      expect(v('abc124'), 'Las contraseñas no coinciden');
      expect(v('abc123'), isNull);
    });
    test('teléfono opcional', () {
      expect(Validadores.telefonoOpcional(''), isNull);
      expect(Validadores.telefonoOpcional('12'), isNotNull);
      expect(Validadores.telefonoOpcional('71234567'), isNull);
    });
    test('título de recordatorio', () {
      expect(Validadores.titulo(' '), 'Escribe un título');
      expect(Validadores.titulo('ab'), 'Mínimo 3 caracteres');
      expect(Validadores.titulo('a' * 61), 'Máximo 60 caracteres');
      expect(Validadores.titulo('Control'), isNull);
    });
  });

  group('Modelo CentroSalud (datos desde Supabase)', () {
    final mapa = {
      'id': 'x',
      'nombre': 'Centro X',
      'tipo': 'posta',
      'ciudad': 'La Paz',
      'zona': 'Centro',
      'direccion': 'Calle 1',
      'telefono': '2-000-0000',
      'latitud': -16.4958,
      'longitud': -68.1335,
      'abierto_24h': false,
      'hora_apertura': '08:00:00',
      'hora_cierre': '16:00:00',
      'dias_atencion': [1, 2, 3, 4, 5],
      'atiende_emergencias': false,
      'descripcion': 'd',
      'servicios': ['Vacunas'],
    };

    test('se convierte desde la fila de la vista v_centros', () {
      final c = CentroSalud.desdeMapa(mapa);
      expect(c.tipo, TipoCentro.posta);
      expect(c.horaApertura, '08:00');
      expect(c.servicios, ['Vacunas']);
      expect(c.horarioTexto, 'Lunes a viernes, 08:00 a 16:00');
      expect(c.distanciaTexto(Ubicacion.referencia), '0 m');
    });

    test('abierto según día y hora', () {
      final c = CentroSalud.desdeMapa(mapa);
      expect(c.estaAbierto(DateTime(2026, 11, 16, 10)), isTrue); // lunes 10:00
      expect(c.estaAbierto(DateTime(2026, 11, 16, 16)), isFalse); // cierre
      expect(c.estaAbierto(DateTime(2026, 11, 15, 10)), isFalse); // domingo
    });

    test('distancia Haversine aproximada', () {
      const plaza = Ubicacion.referencia;
      const elAlto = Ubicacion(-16.5390, -68.1690);
      expect(plaza.distanciaKm(elAlto), closeTo(6.1, 0.3));
    });
  });

  test('Recordatorio se serializa en UTC para la base de datos', () {
    final r = Recordatorio(
        titulo: ' Cita ', fechaHora: DateTime.utc(2026, 12, 1, 14));
    final m = r.aMapa();
    expect(m['titulo'], 'Cita');
    expect(m['tipo'], 'cita');
    expect(m['fecha_hora'], '2026-12-01T14:00:00.000Z');
  });

  group('Ajustes persistentes (HU-05 y modo oscuro HU-06)', () {
    test('valores por defecto', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await AjustesController.cargar();
      expect(a.textoGrande, isFalse);
      expect(a.altoContraste, isFalse);
      expect(a.modoTema, ThemeMode.system);
    });

    test('se mantienen al volver a abrir la app', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await AjustesController.cargar();
      await a.cambiarTextoGrande(true);
      await a.cambiarAltoContraste(true);
      await a.cambiarModoTema(ThemeMode.dark);

      // "Reabrir": nuevo controlador leyendo el mismo almacenamiento.
      final b = await AjustesController.cargar();
      expect(b.textoGrande, isTrue);
      expect(b.altoContraste, isTrue);
      expect(b.modoTema, ThemeMode.dark);
    });
  });

  group('Mensajes de error de autenticación', () {
    test('sin internet no se confunde con la contraseña', () {
      final e = AuthRetryableFetchException(
          message: 'ClientException with SocketException: Failed host lookup, '
              'uri=https://x.supabase.co/auth/v1/token?grant_type=password');
      expect(mensajeError(e), contains('Sin conexión'));
    });
    test('credenciales inválidas', () {
      expect(mensajeError(const AuthException('Invalid login credentials')),
          'Correo o contraseña incorrectos.');
    });
    test('contraseña débil al registrarse', () {
      final e = AuthWeakPasswordException(
          message: 'Password should be at least 6 characters',
          statusCode: '422',
          reasons: const ['length']);
      expect(mensajeError(e), 'La contraseña no cumple los requisitos.');
    });
  });

  group('Registro con correo ya existente (HU-07)', () {
    test('Supabase responde sin identidades: se detecta el duplicado', () {
      expect(correoYaRegistrado(const []), isTrue);
      expect(correoYaRegistrado(const ['email']), isFalse);
      expect(correoYaRegistrado(null), isFalse);
    });
    test('el mensaje dice que el correo ya está registrado', () {
      expect(mensajeError(const AuthException('User already registered')),
          startsWith('Este correo ya está registrado'));
    });
  });
}
