# SaludCerca · Notas técnicas del Sprint 3 (consumo de APIs)

Material de base para el documento maestro del Sprint 3. Todo lo que aquí se cita está en
la rama `sprint3` del repositorio y en la carpeta `sprint3-evidencias/`.

- **Fecha de entrega:** 23/11/2026
- **Objetivo del sprint:** que la app consuma APIs por HTTPS para mostrar farmacias de turno,
  ordenar por cercanía con el GPS, ver todo en un mapa y avisar del clima, con manejo de
  errores, pruebas automáticas y evidencias en Android e iOS.
- **Plataformas:** Android (emulador Pixel 9, Android 17) e iOS (simulador iPhone 17, iOS 26.5),
  misma base de código Flutter 3.47.9 / Dart 3.13.7.

## 1. Historias de usuario del sprint

| HU | Historia | Pts | Estado | Dónde está |
|---|---|---|---|---|
| HU‑03 | Como usuario quiero ver las farmacias de turno de hoy y de mañana cerca de mí | 5 | Hecho | Pestaña **Farmacias** (`lib/screens/farmacias_screen.dart`) |
| HU‑13 | Como usuario quiero que la app detecte mi ubicación para ver primero lo más cercano | 5 | Hecho | `lib/services/ubicacion_servicio.dart`, `lib/widgets/panel_ubicacion.dart` |
| HU‑12 | Como usuario quiero un mapa interactivo con farmacias y centros | 5 | Hecho | `lib/screens/mapa_screen.dart` |
| (API clima) | Como adulto mayor quiero saber el clima y recibir consejos de salud | — | Hecho (parte del objetivo de APIs) | `lib/widgets/tarjeta_clima.dart`, `lib/models/clima.dart` |

- HU‑11 (instalación en Android e iPhone reales) ya estaba hecha en el Sprint 2.
- **HU‑14 (alarma de medicamento) y HU‑15 (consejos de salud preventiva) pasan al Sprint 4.**
  Los avisos del clima son un primer paso hacia HU‑15, pero no la completan.
- Velocidad del sprint: 15 puntos de historia comprometidos y terminados (3 HU de 5 puntos).

### Criterios de aceptación cumplidos

**HU‑03**
1. Lista de farmacias de turno de hoy, ordenada por distancia. ✔
2. Filtro por ciudad (La Paz / El Alto) y por día (hoy / mañana). ✔
3. Etiqueta "Abierto ahora" si el turno está vigente; "Próximo turno" si aún no empieza. ✔
4. Detalle con dirección, horario del turno, teléfono y botón "Ver en el mapa". ✔
5. Solo usuarios autenticados pueden leer; nadie puede escribir desde la app (RLS). ✔

**HU‑13**
1. La app pide permiso de ubicación "mientras se usa la app". ✔
2. Con permiso, centros y farmacias se ordenan por cercanía al teléfono. ✔
3. Muestra la dirección aproximada del usuario (Nominatim inverso). ✔
4. Sin GPS, sin permiso, con GPS lento o fuera de La Paz/El Alto usa Plaza Murillo y dice por qué. ✔
5. Botón "Actualizar mi ubicación". ✔

**HU‑12**
1. Mapa de OpenStreetMap con zoom y desplazamiento. ✔
2. Marcadores diferenciados de centros, farmacias de turno, usuario y lugar buscado. ✔
3. Filtros por capa (centros / farmacias). ✔
4. Tocar un marcador abre la ficha; desde un centro se llega al detalle. ✔
5. Buscador de direcciones (Nominatim) limitado a La Paz y El Alto. ✔
6. Atribución "© colaboradores de OpenStreetMap" visible. ✔
7. Marcadores de al menos 48 dp / 44 pt (accesibilidad). ✔

## 2. APIs consumidas

| # | API | Tipo | Para qué | Seguridad |
|---|---|---|---|---|
| 1 | **Supabase Auth** | REST propia del backend | Inicio de sesión; devuelve un **JWT** (expira en 3600 s) | HTTPS, anon key, contraseña |
| 2 | **Supabase REST (PostgREST)** | REST propia del backend | Centros, favoritos, recordatorios, perfil y **farmacias de turno** | HTTPS, `apikey` + `Authorization: Bearer <JWT>`, RLS |
| 3 | **Open-Meteo** | REST pública, sin clave | Clima actual, UV, mín./máx., probabilidad de lluvia | HTTPS |
| 4 | **Nominatim (OpenStreetMap)** | REST pública, sin clave | Buscar direcciones y obtener la dirección del usuario | HTTPS, máx. 1 solicitud/s, `User-Agent` propio |
| 5 | **Teselas de OpenStreetMap** | HTTP de imágenes | Dibujar el mapa | HTTPS, `User-Agent` propio |

No se creó una API propia: el backend es Supabase, que ya expone la API REST generada a
partir de las tablas y protegida con RLS.

### 2.1 Endpoints

| Método | Endpoint | Parámetros principales | Respuesta |
|---|---|---|---|
| POST | `/auth/v1/token?grant_type=password` | cuerpo `{email, password}` | `access_token` (JWT), `refresh_token`, `user` |
| GET | `/rest/v1/turnos_farmacia` | `select=id,fecha,hora_inicio,hora_fin,farmacias!inner(...)`, `fecha=eq.AAAA-MM-DD`, `activo=eq.true`, opcional `farmacias.ciudad=eq.El Alto` | Lista de turnos con la farmacia embebida |
| GET | `/rest/v1/v_centros` | `select=*`, filtros `ciudad`, `tipo`, `atiende_emergencias`, `or=(nombre.ilike.*x*,zona.ilike.*x*)` | Centros con sus servicios |
| GET | `https://api.open-meteo.com/v1/forecast` | `latitude`, `longitude`, `current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,is_day`, `daily=uv_index_max,temperature_2m_min,temperature_2m_max,precipitation_probability_max`, `timezone=America/La_Paz`, `forecast_days=1` | Objeto `current` y arreglos `daily` |
| GET | `https://nominatim.openstreetmap.org/search` | `q`, `format=jsonv2`, `limit=5`, `countrycodes=bo`, `viewbox=-68.30,-16.38,-68.00,-16.62`, `bounded=1`, `accept-language=es` | Lista de lugares (`lat`, `lon` como texto, `name`, `display_name`) |
| GET | `https://nominatim.openstreetmap.org/reverse` | `lat`, `lon`, `format=jsonv2`, `zoom=16`, `accept-language=es` | Objeto con `address` (`road`, `quarter`, `city`…) |
| GET | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | zoom y tesela | Imagen PNG 256×256 |

### 2.2 Ejemplos reales de solicitud y respuesta

Registros completos (con URL, claves y JWT ocultos) en `sprint3-evidencias/registros/`:
`supabase_rest.txt`, `openmeteo_200.txt`, `openmeteo_400.txt`, `nominatim_search_200.txt`,
`nominatim_reverse_200.txt`.

**Inicio de sesión (Supabase Auth)**

```http
POST https://<proyecto>.supabase.co/auth/v1/token?grant_type=password
apikey: <anon-key>
Content-Type: application/json

{"email": "vladi@saludcerca.app", "password": "********"}
```

```json
HTTP 200
{ "access_token": "<JWT>", "token_type": "bearer", "expires_in": 3600,
  "refresh_token": "<oculto>", "user": { "email": "vladi@saludcerca.app", "role": "authenticated" } }
```

**Farmacias de turno de hoy (API REST de Supabase)**

```http
GET https://<proyecto>.supabase.co/rest/v1/turnos_farmacia?select=id,fecha,hora_inicio,hora_fin,farmacias!inner(id,nombre,ciudad,zona,direccion,telefono,latitud,longitud)&fecha=eq.2026-11-23&activo=eq.true
apikey: <anon-key>
Authorization: Bearer <JWT>
```

```json
HTTP 200
[
  { "id": "7f50067f-…", "fecha": "2026-11-23", "hora_inicio": "08:00:00", "hora_fin": "08:00:00",
    "farmacias": { "nombre": "Farmacia Sopocachi Central", "ciudad": "La Paz", "zona": "Sopocachi",
                   "direccion": "Av. 6 de Agosto N° 2050, Sopocachi", "telefono": "2-100-0002",
                   "latitud": -16.509, "longitud": -68.1255 } },
  … 4 farmacias en total (2 La Paz, 2 El Alto)
]
```

**Clima (Open-Meteo)**

```http
GET https://api.open-meteo.com/v1/forecast?latitude=-16.4958&longitude=-68.1335&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,is_day&daily=uv_index_max,temperature_2m_min,temperature_2m_max,precipitation_probability_max&timezone=America%2FLa_Paz&forecast_days=1
User-Agent: SaludCerca/0.3 (app academica UPDS; https://github.com/VladDur/saludcerca)
```

```json
HTTP 200
{ "timezone": "America/La_Paz", "elevation": 3645.0,
  "current": { "time": "2026-11-23T10:45", "temperature_2m": 20.2, "apparent_temperature": 18.8,
               "relative_humidity_2m": 12, "precipitation": 0.0, "weather_code": 3,
               "wind_speed_10m": 9.7, "is_day": 1 },
  "daily": { "time": ["2026-11-23"], "uv_index_max": [11.10], "temperature_2m_min": [7.7],
             "temperature_2m_max": [22.3], "precipitation_probability_max": [18] } }
```

Con esos datos la app muestra "20 °C, Nublado" y el aviso **"Radiación UV muy alta (11)"**.

**Buscar una dirección (Nominatim)**

```http
GET https://nominatim.openstreetmap.org/search?q=Plaza+Avaroa&format=jsonv2&limit=5&countrycodes=bo&viewbox=-68.30,-16.38,-68.00,-16.62&bounded=1&accept-language=es
User-Agent: SaludCerca/0.3 (app academica UPDS; https://github.com/VladDur/saludcerca)
```

```json
HTTP 200
[ { "lat": "-16.5103129", "lon": "-68.1267271", "name": "Plaza Abaroa",
    "display_name": "Plaza Abaroa, Kantutani, Sopocachi, Cotahuma, Municipio Nuestra Señora de La Paz, …, Bolivia" },
  { "name": "Plaza Eduardo Avaroa", "display_name": "Plaza Eduardo Avaroa, Distrito 4, El Alto, …" } ]
```

**Dirección del usuario (Nominatim inverso)**: `GET /reverse?lat=-16.51000&lon=-68.12700&format=jsonv2&zoom=16&accept-language=es`
→ HTTP 200 con `address.road = "Calle Belisario Salinas"`, `address.quarter = "Sopocachi"`,
`address.city = "Municipio Nuestra Señora de La Paz"`. La app lo resume como
**"Calle Belisario Salinas, Sopocachi, La Paz"**.

### 2.3 Códigos HTTP observados y cómo los maneja la app

| Código | Cuándo ocurrió (evidencia) | Qué ve el usuario |
|---|---|---|
| 200 | Todas las consultas correctas | Datos |
| 400 | Supabase Auth con contraseña incorrecta (`invalid_credentials`); Open-Meteo con latitud −200 (`"error": true, "reason": "Latitude must be in range…"`) | "Correo o contraseña incorrectos." / "El servicio del clima respondió con un error (400)." |
| 401 | API REST sin JWT (rol `anon`, código `42501`) o con un JWT inválido (`PGRST301`) | La app no llega a este caso sin sesión (AuthGate); si el JWT expira: "Tu sesión expiró. Vuelve a iniciar sesión." |
| 403 | El usuario intenta insertar en `farmacias` (`42501 permission denied`) | "No tienes permiso para esta acción." |
| 404 | Tabla inexistente en PostgREST (`PGRST205`); Open-Meteo con una ruta inexistente (prueba E2E) | "Esta función todavía no está disponible en el servidor." / "No encontramos información del clima (error 404)." |
| 429 | Exceso de solicitudes (Nominatim / Open-Meteo); simulado en pruebas | "Hiciste muchas consultas seguidas. Espera unos segundos." |
| 5xx | Servidor caído; simulado en pruebas (500 y 503) | "El servicio del clima no está disponible ahora (error 500). Intenta más tarde." |
| — | Sin internet (`SocketException`/`ClientException`) | "Sin conexión a internet. No pudimos cargar …" |
| — | Más de 10 s sin respuesta (timeout) | "El servicio de … tardó demasiado en responder. Intenta otra vez." |
| — | JSON mal formado o con campos faltantes | "Recibimos datos del … que no entendemos. Intenta más tarde." |

En todos los casos la pantalla muestra un estado de error con el botón **Reintentar** (clima,
farmacias, mapa) y el resto de la app sigue funcionando (si falla el clima, la lista de centros
se ve igual).

## 3. Base de datos (Supabase)

Nuevas tablas en `supabase/schema.sql` (sección "SPRINT 3") y datos en `supabase/seed.sql`:

```
farmacias 1──N turnos_farmacia
```

| Tabla | Columnas | Restricciones |
|---|---|---|
| `farmacias` | id (uuid), nombre, ciudad, zona, direccion, telefono, latitud, longitud, activo, creado_en | `nombre` único; `ciudad in ('La Paz','El Alto')`; lat/lng en rango |
| `turnos_farmacia` | id, farmacia_id (FK), fecha (date), hora_inicio, hora_fin, activo, creado_en | único `(farmacia_id, fecha)`; índice por fecha |

- **RLS:** `select to authenticated using (activo)` en ambas tablas. Sin políticas de escritura,
  `revoke insert, update, delete … from authenticated` y `revoke all … from anon`.
- **Datos de prueba:** 12 farmacias ficticias (6 en La Paz, 6 en El Alto) y 496 turnos
  (desde el 20/11/2026 hasta el 23/03/2027). Rotación: cada día hay 2 farmacias de turno en
  cada ciudad (`(días desde 01/01/2026 + n) mod 3 = 0`).
- **Turno de 24 h:** empieza el día `fecha` a las 08:00 y termina al día siguiente a las 08:00.
  Antes de las 08:00 la app consulta el turno del día anterior (`fechaTurnoVigente`).
- Ejecutado en el SQL Editor el 23/11/2026; resultado: `farmacias = 12`, `turnos = 496`.

## 4. Arquitectura y decisiones técnicas

```
Pantallas (screens/, widgets/)
   │  AppScope.de(context) → Dependencias
   ▼
Interfaces: repositorios (data/repositorios.dart) y servicios (services/*.dart)
   │
   ├── SupabaseFarmaciasRepositorio ……… API REST de Supabase (supabase_flutter)
   ├── OpenMeteoClimaServicio ─┐
   ├── NominatimServicio ──────┼── ApiCliente (package:http): HTTPS, timeout, User-Agent,
   │                           │    códigos HTTP → ApiException, registro de cada solicitud
   └── GpsUbicacionServicio …… geolocator (GPS del teléfono)
Modelos (models/): Farmacia, TurnoFarmacia, Clima, AvisoSalud, LugarEncontrado, Ubicacion
```

Decisiones:

1. **Servicios y modelos separados.** Cada API tiene una interfaz (`ClimaServicio`,
   `GeocodificacionServicio`, `UbicacionServicio`, `FarmaciasRepositorio`) y una implementación
   real. Las pruebas cambian la implementación por una falsa (`test/fakes.dart`).
2. **Un solo cliente HTTP (`ApiCliente`)** para Open-Meteo y Nominatim: rechaza URLs que no son
   HTTPS, corta a los 10 s, envía `User-Agent` y convierte toda falla en `ApiException` con un
   mensaje en español. Así el manejo de errores es igual en toda la app.
3. **OpenStreetMap en lugar de Google Maps:** no necesita clave ni tarjeta de crédito, los datos
   son abiertos y funciona igual en Android e iOS con `flutter_map`.
4. **Política de Nominatim:** `LimitadorSolicitudes` garantiza como máximo 1 solicitud por
   segundo (cola), la búsqueda solo se lanza al pulsar "Buscar" (no en cada letra), hay caché en
   memoria y la búsqueda se limita a La Paz y El Alto (`viewbox` + `bounded=1`).
5. **Open-Meteo** porque es gratuita, sin clave y da índice UV, que es importante en La Paz
   (UV 11 el día de la prueba). Caché de 15 minutos para ahorrar datos móviles.
6. **Ubicación con respaldo:** si no hay GPS, permiso o el usuario está a más de 40 km de Plaza
   Murillo (por ejemplo, un emulador en California), se usa Plaza Murillo y se explica el motivo.
   La app nunca queda bloqueada por la ubicación.
7. **Permisos mínimos:** solo ubicación "mientras se usa la app"
   (`ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` en Android, `NSLocationWhenInUseUsageDescription`
   en iOS). No se pide ubicación en segundo plano.
8. **Claves fuera del repositorio:** la URL y la anon key de Supabase siguen en `env.json`
   (en `.gitignore`). Open-Meteo y Nominatim no usan clave.
9. **Navegación:** se agregó la pestaña **Farmacias** (5 pestañas). El mapa se abre desde el
   ícono de mapa en Centros y Farmacias, y desde "Ver en el mapa" en cada detalle.

### Fragmentos de código relevantes

**Cliente HTTP con manejo de errores** (`lib/services/api_cliente.dart`)

```dart
Future<Object?> getJson(Uri uri, {required String servicio}) async {
  if (uri.scheme != 'https') {
    throw ArgumentError('Solo se permiten URLs HTTPS: $uri');
  }
  http.Response r;
  try {
    r = await _http.get(uri, headers: const {
      'User-Agent': userAgent,
      'Accept': 'application/json',
      'Accept-Language': 'es',
    }).timeout(tiempoMaximo);
  } on TimeoutException {
    throw ApiException(TipoErrorApi.tiempoAgotado, servicio);
  } on SocketException catch (e) {
    throw ApiException(TipoErrorApi.sinConexion, servicio, detalle: e.message);
  } on http.ClientException catch (e) {
    throw ApiException(TipoErrorApi.sinConexion, servicio, detalle: e.message);
  }
  final c = r.statusCode;
  if (c == 429) throw ApiException(TipoErrorApi.limiteSolicitudes, servicio, codigoHttp: c);
  if (c == 404) throw ApiException(TipoErrorApi.noEncontrado, servicio, codigoHttp: c);
  if (c >= 500) throw ApiException(TipoErrorApi.servidor, servicio, codigoHttp: c);
  if (c < 200 || c >= 300) {
    throw ApiException(TipoErrorApi.respuestaHttp, servicio, codigoHttp: c);
  }
  try {
    return jsonDecode(utf8.decode(r.bodyBytes));
  } on FormatException catch (e) {
    throw ApiException(TipoErrorApi.formatoInvalido, servicio, codigoHttp: c, detalle: e.message);
  }
}
```

**Farmacias de turno con la API REST de Supabase** (`lib/data/supabase/supabase_repositorios.dart`)

```dart
var consulta = _db
    .from('turnos_farmacia')
    .select('id, fecha, hora_inicio, hora_fin, '
        'farmacias!inner(id, nombre, ciudad, zona, direccion, telefono, latitud, longitud)')
    .eq('fecha', fechaIso(fecha))
    .eq('activo', true);
if (ciudad != null) consulta = consulta.eq('farmacias.ciudad', ciudad);
final filas = await consulta;
return filas.map(TurnoFarmacia.desdeMapa).toList();
```

**Límite de 1 solicitud por segundo para Nominatim** (`lib/services/geocodificacion_servicio.dart`)

```dart
Future<T> ejecutar<T>(Future<T> Function() tarea) {
  final resultado = _cola.then((_) async {
    final ultima = _ultima;
    if (ultima != null) {
      final falta = intervalo - DateTime.now().difference(ultima);
      if (falta > Duration.zero) await Future.delayed(falta);
    }
    _ultima = DateTime.now();
    return tarea();
  });
  _cola = resultado.then((_) {}, onError: (_) {});
  return resultado;
}
```

**Ubicación con respaldo** (`lib/services/ubicacion_servicio.dart`)

```dart
if (!await Geolocator.isLocationServiceEnabled()) {
  return const ResultadoUbicacion.referencia('El GPS está apagado');
}
var permiso = await Geolocator.checkPermission();
if (permiso == LocationPermission.denied) {
  permiso = await Geolocator.requestPermission();
}
if (permiso == LocationPermission.denied) {
  return const ResultadoUbicacion.referencia('No diste permiso de ubicación');
}
final p = await Geolocator.getCurrentPosition(
  locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
);
return evaluarPosicion(Ubicacion(p.latitude, p.longitude)); // > 40 km → Plaza Murillo
```

**Avisos de salud según el clima** (`lib/models/clima.dart`)

```dart
if (uvMaximo >= 8) {
  r.add(AvisoSalud(TipoAviso.uv, 'Radiación UV muy alta (${uvMaximo.round()})',
      'Usa sombrero, lentes y bloqueador. Evita el sol de 10:00 a 15:00.'));
}
if (minima <= 3 || sensacion <= 5) {
  r.add(const AvisoSalud(TipoAviso.frio, 'Frío intenso',
      'Abrígate bien, sobre todo al salir temprano o de noche, y toma líquidos tibios.'));
}
if (estaLloviendo || probabilidadLluvia >= 60) { /* aviso de lluvia */ }
```

**Mapa con teselas OSM** (`lib/screens/mapa_screen.dart`)

```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.example.saludcerca',
  tileProvider: NetworkTileProvider(headers: {'User-Agent': ApiCliente.userAgent}),
),
MarkerLayer(markers: marcadores),
const RichAttributionWidget(attributions: [
  TextSourceAttribution('© colaboradores de OpenStreetMap'),
]),
```

## 5. Pruebas automáticas

| Archivo | Tipo | Cantidad | Qué prueba |
|---|---|---|---|
| `test/apis_test.dart` | Unitarias | 30 | `ApiCliente` (200, HTTPS obligatorio, 400/403/404/429/500/503, JSON mal formado, sin conexión, timeout); Open-Meteo (URL, conversión de respuesta real, caché, campos faltantes, avisos); Nominatim (URL, búsqueda, inversa, "Unable to geocode", lat inválida, mínimo 3 letras, 1 solicitud/s); ubicación (dentro/fuera de cobertura, orden por cercanía); turnos (conversión, vigencia de 24 h, cambio a las 08:00, cambio de mes, formato inválido) |
| `test/sprint3_widget_test.dart` | Widgets | 14 | Panel de ubicación con GPS y sin permiso; tarjeta de clima con avisos, error sin red + Reintentar, 500 vs timeout; farmacias ordenadas, filtros ciudad/mañana, detalle, error + Reintentar; mapa con capas, búsqueda, error 429, toque de marcador; 5 pestañas sin desbordes con texto grande |
| `test/unidad_test.dart`, `test/widget_test.dart` | Unitarias y widgets (Sprint 2) | 32 | Siguen en verde tras los cambios |
| `integration_test/sprint3_test.dart` | End-to-end con servicios reales | 1 recorrido | Login (JWT), ubicación + clima + dirección, farmacias hoy/El Alto/mañana/detalle/mapa, RLS de solo lectura, mapa con búsqueda real, marcador de centro, errores reales (404 de Open-Meteo y timeout de Nominatim) |

Resultados (23/11/2026):

| Prueba | Android (Pixel 9, Android 17) | iOS (iPhone 17, iOS 26.5) |
|---|---|---|
| `flutter test` (76 unitarias y de widgets) | 76 / 76 en verde | (las mismas, independientes de la plataforma) |
| `flutter analyze` | Sin problemas | — |
| End-to-end `sprint3_test.dart` con servicios reales | **Pasa** (2 min 11 s) | **Pasa** (1 min 42 s) |

Salidas en `sprint3-evidencias/registros/` (`flutter_test.txt`, `flutter_analyze.txt`,
`prueba_e2e_android.txt`, `prueba_e2e_ios.txt`, `prueba_e2e_ios_capturas.txt`).
Ejemplo de lo que registra la app durante la prueba:

```
[AUTH] sesión iniciada, JWT con expiración 1795450399
[API] GET nominatim.openstreetmap.org/reverse -> 200 (350 ms)
[API] GET api.open-meteo.com/v1/forecast -> 200 (664 ms)
[RLS] insert en farmacias rechazado: 42501 permission denied for table farmacias
[API] GET nominatim.openstreetmap.org/search -> 200 (228 ms)
[API] GET api.open-meteo.com/v1/no-existe -> 404 (630 ms)
[API] GET nominatim.openstreetmap.org/search -> TIMEOUT (23 ms)
```

## 6. Defectos encontrados y corregidos durante el sprint

| # | Defecto | Cómo se detectó | Corrección |
|---|---|---|---|
| D‑01 | Al cambiar el filtro de farmacias y al pulsar "Reintentar" en el clima se lanzaba la excepción *"setState() callback argument returned a Future"* y la lista no se actualizaba. | Prueba de widgets "filtra por ciudad y consulta el turno de mañana". | `setState(() { _futuro = _consultar(); })` con llaves, para no devolver el `Future`. |
| D‑02 | Si una API fallaba muy rápido (antes de que el `FutureBuilder` se suscribiera), el error se reportaba como "no manejado". | Prueba "HTTP 500 y timeout tienen mensajes distintos". | Se marca el `Future` con `..ignore()`; el `FutureBuilder` igual recibe y muestra el error. |
| D‑03 | En el mapa, el punto azul del usuario tapaba los marcadores cercanos y no se podía tocar la farmacia que estaba al lado. | Prueba "tocar un marcador de farmacia abre su detalle". | El marcador del usuario va dentro de `IgnorePointer`. |
| D‑04 | La dirección del usuario se veía como "Calle Belisario Salinas, Cotahuma, Municipio Nuestra Señora de La Paz", larga y confusa. | Revisión de la respuesta real de Nominatim. | Se prioriza `quarter` (Sopocachi) y se limpia el nombre del municipio: "Calle Belisario Salinas, Sopocachi, La Paz". |
| D‑05 | Con la tarjeta de clima, los centros quedaban más abajo y 4 pruebas del Sprint 2 fallaban porque `ListView` no construye lo que no se ve. | `flutter test` tras integrar el clima. | Las pruebas ahora desplazan la lista hasta el elemento (helper `visible`). |
| D‑06 | El emulador de Android trae por defecto una ubicación en California; las distancias salían en miles de km. | Primera corrida end-to-end en el emulador. | Regla de cobertura de 40 km: fuera de ella se usa Plaza Murillo con el aviso "Estás fuera de La Paz y El Alto". Para la prueba se fijó la posición con proveedores de ubicación de prueba (`adb shell cmd location providers set-test-provider-location`). |
| D‑07 | "El servicio de el mapa tardó demasiado…": error gramatical en los mensajes de error. | Revisión de las capturas de Android. | `ApiException` arma "del clima" / "del mapa". |
| D‑08 | Al pulsar "Reintentar" con otras dependencias, la tarjeta de clima mostraba datos viejos. | Prueba end-to-end (sección de errores). | La prueba crea un árbol nuevo (`KeyedSubtree` con `UniqueKey`); la app real no cambia de dependencias en ejecución. |

**Incidencias del entorno (no son defectos de la app):**
- `flutter drive` desinstala la app al terminar, y con eso iOS y Android olvidan el permiso de
  ubicación. Antes de cada corrida se instala la app y se concede el permiso
  (`xcrun simctl privacy … grant location`, `adb shell pm grant …`).
- En el simulador de iOS la pantalla se quedaba congelada mientras `flutter drive` estaba
  conectado y las capturas salían en blanco. La prueba se ejecutó también directamente en el
  simulador y las capturas se tomaron con `xcrun simctl io screenshot` cuando la prueba
  avisaba `[CAPTURA]`. La prueba pasó en ambas formas.
- En el emulador de Android apareció "Google Play services isn't responding"; se reinició el
  emulador.

## 7. Evidencias

Carpeta `sprint3-evidencias/` (mapa captura → sección en `sprint3-evidencias/LEEME.md`):

- Capturas `NN_nombre_android.png` y `NN_nombre_ios.png` generadas por la prueba end-to-end.
- `registros/`: solicitudes y respuestas reales (Supabase, Open-Meteo, Nominatim), salida de
  `flutter test`, `flutter analyze` y de la prueba end-to-end en cada plataforma (incluye las
  líneas `[API] GET … -> 200 (123 ms)` que la app registra por cada solicitud).
- `feedback/eval_stakeh_grupo2_s2.xlsx`: evaluación de stakeholders del Sprint 2.

## 8. Retroalimentación recibida del Sprint 2 (stakeholders)

3 evaluaciones del grupo 2 sobre HU‑02, 05, 06, 07, 08, 09, 10 y 11:

| Criterio | Resultado |
|---|---|
| Valor percibido | Alto, resuelve un problema importante (3 de 3) |
| Calidad | Excelente, listo para producción (3 de 3) |
| Nota general | 100 / 100 (3 de 3) |
| Lo que gustó | Interfaz fácil e intuitiva; se corrigieron los problemas del Sprint 1; funcionalidades correctas; amenidades |
| Lo que mejorarían | "Colores de la App" (1 de 3); las otras dos: nada |
| Prioridad para el siguiente sprint | Crítico (1), Importante (1), No prioritario (1) |

Acción: la sugerencia de colores se registra en el Product Backlog para revisarla en el
Sprint 4 junto con la beta con adultos mayores (HU‑17), para decidir con usuarios reales.

## 9. Pendientes para el Sprint 4

- HU‑14 alarma de medicamentos y HU‑15 consejos de salud preventiva (reprogramadas).
- HU‑16 farmacias de turno sin conexión (guardar la última consulta en el teléfono).
- Panel web del ADMINISTRADOR para cargar farmacias y turnos (hoy se cargan por SQL).
- Botón "Llamar" con `url_launcher` y "Cómo llegar".
- Revisar la paleta de colores según el feedback.
- Para producción con muchos usuarios, usar un proveedor de teselas y geocodificación con
  acuerdo de uso (la política de OSM no permite uso intensivo de sus servidores públicos).
