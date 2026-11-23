# Evidencias del Sprint 3

Capturas generadas automáticamente por la prueba end-to-end
`integration_test/sprint3_test.dart` contra los servicios reales (Supabase, Open-Meteo,
Nominatim y teselas de OpenStreetMap), en el **emulador Pixel 9 (Android 17)** y el
**simulador iPhone 17 (iOS 26.5)**, con la ubicación fijada en Sopocachi, La Paz
(-16.5100, -68.1270). Cada captura existe en las dos versiones: `NN_nombre_android.png` y
`NN_nombre_ios.png`.

| Captura | Qué muestra | HU / sección del documento |
|---|---|---|
| 00_permiso_ubicacion_ios | Pedido de permiso de ubicación del sistema, con el texto de `NSLocationWhenInUseUsageDescription` | HU‑13 · permisos |
| 01_centros_ubicacion_clima | "Cerca de ti: Calle Belisario Salinas, Sopocachi, La Paz" (Nominatim inverso) y tarjeta de clima de Open-Meteo con aviso de UV muy alto | HU‑13, API de clima |
| 02_centros_por_cercania | Lista de centros ordenada por distancia al GPS | HU‑13 |
| 03_farmacias_turno_hoy | 4 farmacias de turno hoy, ordenadas por cercanía, "Abierto ahora" | HU‑03, API REST Supabase |
| 04_farmacias_el_alto | Filtro por ciudad: 2 farmacias de turno en El Alto | HU‑03 |
| 05_farmacias_manana | Turno de mañana: "Próximo turno" | HU‑03 |
| 06_farmacia_detalle | Detalle: dirección, horario del turno, teléfono, "Ver en el mapa" | HU‑03 |
| 07_mapa_farmacia_enfocada | Mapa OSM centrado en la farmacia elegida (marcador resaltado) | HU‑12 |
| 08_mapa_centros_farmacias | Mapa con 10 centros, 4 farmacias de turno y el usuario; atribución OSM | HU‑12 |
| 09_mapa_busqueda_resultados | Búsqueda "Plaza Avaroa" con Nominatim: lista de resultados | HU‑12, Nominatim |
| 10_mapa_lugar_encontrado | Mapa movido al lugar encontrado, con marcador rojo | HU‑12 |
| 11_mapa_solo_centros | Filtro de capas: solo centros | HU‑12 |
| 12_mapa_marcador_centro | Toque en el marcador de un centro: ficha con "Ver detalle" | HU‑12 |
| 13_error_clima_404 | Manejo de errores: Open-Meteo responde HTTP 404 → mensaje y "Reintentar" | Manejo de errores |
| 14_error_nominatim_timeout | Manejo de errores: Nominatim sin respuesta a tiempo → "tardó demasiado" | Manejo de errores |

## Registros (`registros/`)

| Archivo | Contenido |
|---|---|
| `supabase_rest.txt` | 8 solicitudes reales a Supabase Auth y a la API REST (200, 400, 401, 403, 404) con URL, claves y JWT ocultos |
| `openmeteo_200.txt`, `openmeteo_400.txt` | Respuestas reales de Open-Meteo (correcta y con latitud inválida) |
| `nominatim_search_200.txt`, `nominatim_reverse_200.txt` | Respuestas reales de Nominatim (búsqueda y dirección inversa) |
| `prueba_e2e_android.txt`, `prueba_e2e_ios.txt` | Salida completa de la prueba end-to-end; incluye las líneas `[API] GET … -> código (ms)`, `[AUTH]`, `[RLS]` y `[EVIDENCIA]` |
| `flutter_test.txt` | Salida de `flutter test` (76 pruebas) |
| `flutter_analyze.txt` | Salida de `flutter analyze` |
| `flutter_version.txt`, `dispositivos.txt` | Versión de Flutter y dispositivos usados |

## Retroalimentación (`feedback/`)

`eval_stakeh_grupo2_s2.xlsx`: evaluación de los stakeholders sobre el Sprint 2.
