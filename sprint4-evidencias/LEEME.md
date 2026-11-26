# Evidencias del Sprint 4 (SaludCerca)

Generadas el 26/11/2026 con `integration_test/sprint4_test.dart` contra los servicios
reales (Supabase y Open-Meteo Air Quality) en el emulador Pixel 9 (Android 17) y el
simulador iPhone 17 (iOS 26.5).

| Captura | Qué muestra |
|---|---|
| `01_calidad_aire_consejos_*` | HU-15: tarjeta de calidad del aire con índice US AQI, nivel, PM2,5/PM10 y consejos (aire y UV) |
| `02_recordatorio_boton_dictar_*` | Formulario de recordatorio con el botón «Dictar el título con la voz» |
| `03_recordatorio_escuchando_*` | Estado «Escuchando…» con el texto reconocido en vivo |
| `04_recordatorio_titulo_dictado_*` | El título queda lleno y la app pide revisarlo |
| `05_recordatorio_guardado_*` | Recordatorio guardado en Supabase (luego se hace baja lógica) |
| `06_error_aire_404_*` | Manejo de error HTTP 404 con botón Reintentar |
| `07_error_aire_timeout_*` | Manejo de tiempo agotado |
| `08_farmacia_boton_consultar_android` | Detalle de Farmacia Sopocachi Central con el botón «Consultar» (WhatsApp) |
| `09_consulta_validacion_android` | Diálogo del medicamento con la validación del campo vacío |
| `10_consulta_medicamento_android` | Medicamento escrito, listo para abrir WhatsApp |

- En el emulador y el simulador no hay una persona hablando, así que la prueba usa un
  dictado guionado que entrega «sacar ficha en hospital Miraflores» como lo haría el
  reconocedor (parciales y luego texto final). La pantalla y el guardado son los reales.
  El reconocimiento real (speech_to_text) debe probarse en un teléfono físico.
- iOS: con `flutter drive` la pantalla del simulador queda congelada; la prueba se ejecutó con
  `flutter run -t integration_test/sprint4_test.dart` y las capturas se tomaron con
  `xcrun simctl io screenshot` al ver `[CAPTURA]`.
- `registros/calidad_aire_200.txt` y `calidad_aire_400.txt`: respuestas reales de la API.
- Capturas 08 a 10: `integration_test/sprint4_whatsapp_test.dart` en el emulador Pixel 9 con Supabase real
  (26/11/2026). El emulador no tiene WhatsApp: un servicio de registro comprueba el número y el mensaje
  que se entregarían (`prueba_e2e_whatsapp_android.txt`).
- `flutter_analyze.txt` (sin problemas) y `flutter_test.txt` (120 pruebas en verde, 26/11/2026).
