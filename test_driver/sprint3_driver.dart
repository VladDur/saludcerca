import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Guarda cada captura de la prueba end-to-end del Sprint 3 en
/// sprint3-evidencias/.
///
/// En el simulador de iOS la captura interna a veces sale en blanco; con la
/// variable CAPTURA_SIMCTL=<udid> se toma con `xcrun simctl io screenshot`.
Future<void> main() => integrationDriver(
      onScreenshot: (nombre, bytes, [args]) async {
        final archivo = File('sprint3-evidencias/$nombre.png');
        await archivo.create(recursive: true);
        final udid = Platform.environment['CAPTURA_SIMCTL'];
        if (udid != null && udid.isNotEmpty) {
          final r = await Process.run('xcrun',
              ['simctl', 'io', udid, 'screenshot', '--type=png', archivo.path]);
          if (r.exitCode == 0) return true;
        }
        await archivo.writeAsBytes(bytes);
        return true;
      },
    );
