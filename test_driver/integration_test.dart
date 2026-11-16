import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Guarda cada captura de la prueba end-to-end en sprint2-evidencias/.
Future<void> main() => integrationDriver(
      onScreenshot: (nombre, bytes, [args]) async {
        final archivo = File('sprint2-evidencias/$nombre.png');
        await archivo.create(recursive: true);
        await archivo.writeAsBytes(bytes);
        return true;
      },
    );
