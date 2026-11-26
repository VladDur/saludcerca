import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludcerca/app.dart';
import 'package:saludcerca/core/app_scope.dart';
import 'package:saludcerca/screens/farmacias_screen.dart';
import 'package:saludcerca/screens/mapa_screen.dart';
import 'package:saludcerca/services/api_cliente.dart';
import 'package:saludcerca/services/ubicacion_servicio.dart';

import 'fakes.dart';

/// Pruebas de widgets del Sprint 3 (sin internet): farmacias de turno,
/// ubicación, clima con avisos y estados de error, y mapa.

Future<Dependencias> abrir(WidgetTester tester,
    {FakeFarmacias? farmacias,
    FakeClima? clima,
    FakeGeocodificacion? geo,
    FakeUbicacion? ubicacion,
    Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  MapaScreen.cargarTeselas = false;
  final deps = await crearDependencias(
      conSesion: true,
      prefs: prefs,
      farmacias: farmacias,
      clima: clima,
      geocodificacion: geo,
      ubicacion: ubicacion);
  await tester.pumpWidget(SaludCercaApp(dependencias: deps));
  await tester.pumpAndSettle();
  return deps;
}

Future<void> pestana(WidgetTester tester, String nombre) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text(nombre)));
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('HU-13 ubicación y clima en Centros', () {
    testWidgets('con GPS muestra la dirección (Nominatim) y el clima',
        (tester) async {
      await abrir(tester);
      expect(find.text('Cerca de ti'), findsOneWidget);
      expect(find.text('Sopocachi, La Paz'), findsOneWidget);
      expect(find.text('14 °C'), findsOneWidget);
      expect(find.text('Buen clima para salir. ¡Cuídate!'), findsOneWidget);
    });

    testWidgets('sin permiso usa Plaza Murillo y explica el motivo',
        (tester) async {
      final u = FakeUbicacion()
        ..resultado = const ResultadoUbicacion.referencia(
            'No diste permiso de ubicación');
      await abrir(tester, ubicacion: u);
      expect(
          find.text('Distancias desde Plaza Murillo, La Paz'), findsOneWidget);
      expect(find.text('No diste permiso de ubicación.'), findsOneWidget);
    });

    testWidgets('avisos de salud por UV alto, frío y lluvia', (tester) async {
      final clima = FakeClima()
        ..clima = climaPrueba(uv: 11, minima: 1, lluvia: 70);
      await abrir(tester, clima: clima);
      expect(find.text('Radiación UV muy alta (11)'), findsOneWidget);
      expect(find.text('Frío intenso'), findsOneWidget);
      expect(find.text('Probable lluvia (70 %)'), findsOneWidget);
    });

    testWidgets('error del clima muestra mensaje y Reintentar funciona',
        (tester) async {
      final clima = FakeClima()..error = errorSinRed;
      await abrir(tester, clima: clima);
      expect(find.byKey(const Key('clima_error')), findsOneWidget);
      expect(find.textContaining('Sin conexión a internet'), findsOneWidget);
      // La lista de centros sigue funcionando aunque falle el clima.
      await tester.scrollUntilVisible(find.textContaining('Encontramos'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Encontramos'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      clima.error = null;
      await tocar(tester, find.byKey(const Key('clima_reintentar')));
      expect(find.text('14 °C'), findsOneWidget);
      expect(clima.llamadas, 2);
    });

    testWidgets('HTTP 500 y timeout tienen mensajes distintos', (tester) async {
      final clima = FakeClima()
        ..error = const ApiException(TipoErrorApi.servidor, 'el clima',
            codigoHttp: 500);
      await abrir(tester, clima: clima);
      expect(find.textContaining('(error 500)'), findsOneWidget);
      clima.error = const ApiException(TipoErrorApi.tiempoAgotado, 'el clima');
      await tocar(tester, find.byKey(const Key('clima_reintentar')));
      expect(find.textContaining('tardó demasiado'), findsOneWidget);
    });
  });

  group('HU-03 farmacias de turno', () {
    testWidgets('lista de turno ordenada por cercanía', (tester) async {
      await abrir(tester);
      await pestana(tester, 'Farmacias');
      expect(find.text('3 farmacias de turno hoy'), findsOneWidget);
      final tarjetas = find.byType(TarjetaFarmacia);
      final primera = tester.widget<TarjetaFarmacia>(tarjetas.first);
      expect(primera.turno.farmacia.nombre, 'Farmacia Cercana');
      expect(find.text('Abierto ahora'), findsWidgets);
    });

    testWidgets('filtra por ciudad y consulta el turno de mañana',
        (tester) async {
      final f = FakeFarmacias();
      await abrir(tester, farmacias: f);
      await pestana(tester, 'Farmacias');
      final hoy = f.ultimaFecha!;
      await tocar(tester, find.text('El Alto'));
      expect(find.text('1 farmacia de turno hoy'), findsOneWidget);
      expect(find.text('Farmacia Alteña'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('turno_manana')));
      expect(f.ultimaFecha, DateTime(hoy.year, hoy.month, hoy.day + 1));
      expect(find.text('1 farmacia de turno mañana'), findsOneWidget);
      expect(find.text('Próximo turno'), findsOneWidget);
    });

    testWidgets('detalle con dirección, turno y teléfono', (tester) async {
      await abrir(tester);
      await pestana(tester, 'Farmacias');
      await tocar(tester, find.text('Farmacia Cercana'));
      expect(find.text('Dirección'), findsOneWidget);
      expect(find.text('2-100-000f2'), findsWidgets);
      expect(find.byKey(const Key('farmacia_ver_mapa')), findsOneWidget);
    });

    testWidgets('error de la API REST muestra mensaje y Reintentar',
        (tester) async {
      final f = FakeFarmacias()
        ..error = const ApiException(TipoErrorApi.sinConexion, 'farmacias');
      await abrir(tester, farmacias: f);
      await pestana(tester, 'Farmacias');
      expect(find.textContaining('Sin conexión a internet'), findsOneWidget);
      f.error = null;
      await tocar(tester, find.text('Reintentar'));
      expect(find.text('3 farmacias de turno hoy'), findsOneWidget);
    });
  });

  group('HU-12 mapa', () {
    testWidgets('muestra centros, farmacias y al usuario; filtra capas',
        (tester) async {
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('abrir_mapa')));
      expect(find.text('Centros (3)'), findsOneWidget);
      expect(find.text('Farmacias de turno (3)'), findsOneWidget);
      expect(find.bySemanticsLabel('Tu ubicación'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Centro: ')), findsWidgets);
      await tocar(tester, find.byKey(const Key('mapa_filtro_centros')));
      expect(find.bySemanticsLabel(RegExp('^Centro: ')), findsNothing);
      expect(
          find.bySemanticsLabel(RegExp('^Farmacia de turno: ')), findsWidgets);
    });

    testWidgets('búsqueda de direcciones con Nominatim', (tester) async {
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('abrir_mapa')));
      await tester.enterText(find.byKey(const Key('mapa_buscar')), 'ab');
      await tocar(tester, find.byKey(const Key('mapa_buscar_boton')));
      expect(find.text('Escribe al menos 3 letras.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('mapa_buscar')), 'avaroa');
      await tocar(tester, find.byKey(const Key('mapa_buscar_boton')));
      expect(find.text('Plaza Avaroa'), findsOneWidget);
      await tocar(tester, find.text('Plaza Avaroa'));
      expect(find.byKey(const Key('marcador_busqueda')), findsOneWidget);
      expect(find.byKey(const Key('mapa_resultados')), findsNothing);
    });

    testWidgets('error de Nominatim (429) se muestra en la búsqueda',
        (tester) async {
      final geo = FakeGeocodificacion()
        ..error = const ApiException(TipoErrorApi.limiteSolicitudes, 'el mapa',
            codigoHttp: 429);
      await abrir(tester, geo: geo);
      await tocar(tester, find.byKey(const Key('abrir_mapa')));
      await tester.enterText(find.byKey(const Key('mapa_buscar')), 'avaroa');
      await tocar(tester, find.byKey(const Key('mapa_buscar_boton')));
      expect(find.textContaining('muchas consultas seguidas'), findsOneWidget);
    });

    testWidgets('tocar un marcador de farmacia abre su detalle',
        (tester) async {
      await abrir(tester);
      await pestana(tester, 'Farmacias');
      await tocar(tester, find.byKey(const Key('farmacias_mapa')));
      await tester
          .tap(find.bySemanticsLabel('Farmacia de turno: Farmacia Cercana'));
      await tester.pumpAndSettle();
      expect(find.text('Turno'), findsOneWidget);
    });
  });

  testWidgets('5 pestañas sin desbordes con texto grande', (tester) async {
    await abrir(tester, prefs: {'ajustes.texto_grande': true});
    for (final p in [
      'Farmacias',
      'Favoritos',
      'Recordar',
      'Perfil',
      'Centros'
    ]) {
      await pestana(tester, p);
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });
}
