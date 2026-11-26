# SaludCerca · Sprint 4 (Flutter + Supabase + APIs, rol USUARIO)

App móvil híbrida para encontrar centros de salud y **farmacias de turno** en La Paz y El
Alto, pensada para adultos mayores. Una sola base de código Flutter genera la app de
**Android (APK)** y la de **iOS**. El backend es **Supabase** (PostgreSQL + Auth + Row Level
Security). El Sprint 3 agregó el consumo de **APIs externas** por HTTPS y el Sprint 4 suma una
nueva API REST de **calidad del aire**, recordatorios **por voz** y la consulta de medicamentos
**por WhatsApp**.

## Qué incluye el Sprint 4

| HU | Detalle |
|---|---|
| **HU‑15 Consejos de salud y calidad del aire** | Tarjeta en **Centros** con el índice US AQI, PM2,5, PM10 y UV de la **API Air Quality de Open-Meteo** (GET, HTTPS, sin clave) y consejos para adultos mayores. Caché de 30 min, errores con **Reintentar**. |
| **HU‑22 Recordatorios por voz** | Botón **Dictar el título con la voz** en el formulario de recordatorio (`speech_to_text`, reconocedor del sistema en español). No es una API REST. |
| **HU‑21 Consultar medicamento por WhatsApp** | Botón **Consultar** en el detalle de una farmacia con WhatsApp: pide el medicamento y abre `https://wa.me/591…?text=…` con el mensaje escrito (`url_launcher`). El usuario decide si lo envía. Solo **Farmacia Sopocachi Central** tiene número de prueba. No es una API REST. |
| **HU‑17 Pruebas** | 120 pruebas unitarias y de widgets en verde, 2 pruebas end-to-end nuevas (Android e iOS) y beta con usuarios. |

Evidencias en [`sprint4-evidencias/`](sprint4-evidencias/LEEME.md) y documento final de los 4 sprints
en `sprint4-documento/`.

## Qué incluye el Sprint 3

| HU / módulo | Detalle |
|---|---|
| **HU‑03 Farmacias de turno** | Nueva pestaña **Farmacias**: farmacias de turno de hoy o de mañana, filtro por ciudad, detalle (dirección, turno, teléfono) y "Ver en el mapa". Datos de las tablas nuevas `farmacias` y `turnos_farmacia` (1‑N) por la **API REST de Supabase** con el JWT del usuario y RLS de solo lectura. |
| **HU‑13 Ubicación del teléfono** | Con permiso, la app usa el GPS (`geolocator`) y ordena centros y farmacias por cercanía. Muestra la dirección aproximada ("Calle…, Sopocachi, La Paz") con **Nominatim** (geocodificación inversa). Sin GPS, sin permiso o fuera de La Paz/El Alto usa Plaza Murillo y explica el motivo. |
| **HU‑12 Mapa interactivo** | Mapa de **OpenStreetMap** (`flutter_map`) con marcadores de centros, farmacias de turno y del usuario; filtros por capa; búsqueda de direcciones con **Nominatim**; tocar un marcador abre su ficha. Atribución "© colaboradores de OpenStreetMap". |
| **Clima y avisos de salud** | Tarjeta en **Centros** con el clima actual de **Open-Meteo** (sin clave) y avisos preventivos: UV alto, frío intenso, lluvia y calor. |
| Manejo de errores | Solo HTTPS, tiempo máximo de 10 s, códigos HTTP (404, 429, 5xx…), sin conexión y JSON inesperado se convierten en mensajes claros con botón **Reintentar**. |
| Sprint 2 (se mantiene) | Autenticación, CRUD de recordatorios, favoritos y perfil, HU‑05 accesibilidad y HU‑06 modo oscuro. |

## APIs que usa la app

| API | Uso | URL base | Autenticación |
|---|---|---|---|
| Supabase Auth | Registro e inicio de sesión; entrega un **JWT** | `https://<proyecto>.supabase.co/auth/v1` | anon key + correo y contraseña |
| Supabase REST (PostgREST) | Centros, favoritos, recordatorios, perfil, **farmacias de turno** | `https://<proyecto>.supabase.co/rest/v1` | `apikey` + `Authorization: Bearer <JWT>`; RLS |
| Open-Meteo | Clima actual y del día | `https://api.open-meteo.com/v1/forecast` | Ninguna (gratuita) |
| **Open-Meteo Air Quality** (Sprint 4) | Calidad del aire y UV (HU‑15) | `https://air-quality-api.open-meteo.com/v1/air-quality` | Ninguna (gratuita) |
| Nominatim (OSM) | Buscar direcciones y dirección del usuario | `https://nominatim.openstreetmap.org` | Ninguna; **máx. 1 solicitud/s** y `User-Agent` propio |
| Teselas OSM | Imágenes del mapa | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | Ninguna; `User-Agent` propio |

Integraciones del Sprint 4 que **no** son API REST: el reconocedor de voz del sistema
(`speech_to_text`) y la app WhatsApp (enlace `wa.me` con `url_launcher`).

Los detalles de endpoints, ejemplos de solicitud y respuesta y códigos HTTP están en
[`SPRINT3_NOTAS.md`](SPRINT3_NOTAS.md) (Sprint 3) y en la Parte IV del documento final (Sprint 4).

## Requisitos

- Flutter 3.x estable (probado con Flutter 3.47.9 / Dart 3.13.7)
- Android Studio con un emulador (probado en Pixel 9, Android 17) o un teléfono Android
- Xcode con simulador iOS (probado en iPhone 17, iOS 26.5) — solo en macOS
- Un proyecto de Supabase
- Conexión a internet (las APIs de clima y mapa son públicas)

## Instalación paso a paso

### 1. Base de datos (una sola vez)

1. Entra a <https://supabase.com/dashboard> y abre el proyecto **SaludCerca**.
2. Ve a **SQL Editor → New query**, pega el contenido de `supabase/schema.sql` y pulsa **Run**.
   El script es idempotente: en el Sprint 3 agrega `farmacias` y `turnos_farmacia` con RLS, y en
   el Sprint 4 la columna opcional `farmacias.whatsapp` (formato `591` + 8 dígitos).
3. Repite con `supabase/seed.sql`: carga 10 centros, 16 servicios, 12 farmacias y sus
   turnos (2 en La Paz y 2 en El Alto cada día, durante 4 meses). Si los turnos vencen,
   vuelve a ejecutar el último bloque del archivo.
4. Para probar la consulta por WhatsApp, asigna un celular a una farmacia en el SQL Editor
   (los números reales no se guardan en el repositorio):
   `update farmacias set whatsapp = '5917XXXXXXX' where nombre = 'Farmacia Sopocachi Central';`
5. Opcional para pruebas: en **Authentication → Sign In / Providers → Email** puedes
   desactivar *Confirm email* para que las cuentas nuevas entren sin confirmar el correo.

### 2. Conectar la app

1. En Supabase: **Project Settings → API** (o **API Keys**), copia la *Project URL* y la
   *anon / publishable key*.
2. Copia `env.example.json` como `env.json` y pega esos dos valores:

```json
{
  "SUPABASE_URL": "https://xxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJ... o sb_publishable_..."
}
```

`env.json` está en `.gitignore`: no se sube al repositorio. La anon key es pública por
diseño; la protección de los datos la dan las políticas RLS. Open-Meteo y Nominatim no
necesitan clave.

### 3. Ejecutar

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

La primera vez la app pide permiso de ubicación. Si lo rechazas, sigue funcionando con
Plaza Murillo como referencia. Al tocar **Dictar** por primera vez pide permiso de micrófono y de
reconocimiento de voz.

Generar el APK de Android:

```bash
flutter build apk --release --dart-define-from-file=env.json
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.
Para iOS: `flutter build ios --dart-define-from-file=env.json` (requiere Xcode y firma).

### 4. Pruebas y análisis

```bash
flutter analyze   # análisis estático
flutter test      # 120 pruebas unitarias y de widgets (sin internet: APIs y repositorios falsos)
```

Las pruebas de las APIs (`test/apis_test.dart`) usan `MockClient` para simular respuestas
200, 400, 403, 404, 429, 500 y 503, JSON mal formado, falta de conexión y tiempo agotado.

**Prueba end-to-end del Sprint 3** contra los servicios reales (Supabase, Open-Meteo,
Nominatim y OSM). Guarda las capturas en `sprint3-evidencias/`. Requiere `TEST_EMAIL` y
`TEST_PASSWORD` en `env.json`, y que el dispositivo tenga permiso de ubicación y una
posición en La Paz:

```bash
# Android (emulador): instalar una vez, dar permiso y fijar la posición en Sopocachi
adb shell pm grant com.example.saludcerca android.permission.ACCESS_FINE_LOCATION
adb emu geo fix -68.1270 -16.5100
# iOS (simulador)
xcrun simctl privacy booted grant location com.example.saludcerca
xcrun simctl location booted set -16.5100,-68.1270

flutter drive --driver=test_driver/sprint3_driver.dart \
  --target=integration_test/sprint3_test.dart \
  --dart-define-from-file=env.json -d <id-del-dispositivo>
```

**Pruebas end-to-end del Sprint 4** (calidad del aire real, dictado guionado, errores 404 y tiempo
agotado reales; y consulta por WhatsApp). Guardan las capturas en `sprint4-evidencias/`:

```bash
flutter drive --driver=test_driver/sprint4_driver.dart \
  --target=integration_test/sprint4_test.dart --dart-define-from-file=env.json -d <id>
flutter drive --driver=test_driver/sprint4_driver.dart \
  --target=integration_test/sprint4_whatsapp_test.dart --dart-define-from-file=env.json -d <id>
```

La prueba end-to-end del Sprint 2 sigue disponible con
`--driver=test_driver/integration_test.dart --target=integration_test/app_test.dart`.

## URLs y credenciales de prueba

| Dato | Valor |
|---|---|
| Panel de Supabase | <https://supabase.com/dashboard> → proyecto **SaludCerca** |
| URL de la API de Supabase | `SUPABASE_URL` en `env.json` (se entrega aparte, no se sube a git) |
| Open-Meteo | <https://api.open-meteo.com/v1/forecast> (documentación: <https://open-meteo.com/en/docs>) |
| Open-Meteo Air Quality | <https://air-quality-api.open-meteo.com/v1/air-quality> (documentación: <https://open-meteo.com/en/docs/air-quality-api>) |
| Nominatim | <https://nominatim.openstreetmap.org> (política: <https://operations.osmfoundation.org/policies/nominatim/>) |
| Repositorio | <https://github.com/VladDur/saludcerca> (ramas `sprint2`, `sprint3`; el Sprint 4 se integra al aprobarse) |
| WhatsApp de prueba | Farmacia Sopocachi Central (botón **Consultar**, de turno cada 4 días) |
| Usuario de prueba | `vladi@saludcerca.app` |
| Contraseña de prueba | `Prueba123` |

También puedes crear tu propia cuenta desde la pantalla **Crear una cuenta**.

## Estructura del proyecto

```
lib/
  main.dart                  arranque y dependencias reales (Supabase, APIs, GPS)
  app.dart                   MaterialApp, temas, texto grande y AuthGate
  config/env.dart            URL y anon key (desde --dart-define)
  core/                      validadores, mensajes de error, AppScope (inyección)
  data/repositorios.dart     interfaces de acceso a datos (incluye FarmaciasRepositorio)
  data/supabase/             implementación con Supabase (API REST)
  services/                  Sprint 3: api_cliente (HTTP), clima (Open-Meteo),
                             geocodificacion (Nominatim), ubicacion (GPS)
                             Sprint 4: calidad_aire (Open-Meteo Air Quality), voz
                             (speech_to_text), whatsapp (url_launcher)
  models/                    centro_salud, farmacia, clima, calidad_aire, perfil, favorito, recordatorio
  settings/                  AjustesController (HU‑05 y HU‑06, persistente)
  screens/                   auth, shell (5 pestañas), centros, farmacias, mapa, detalle,
                             favoritos, recordatorios, formulario, perfil
  theme/app_theme.dart       4 temas: claro, oscuro, alto contraste claro/oscuro
  widgets/                   tarjetas, etiquetas, mensajes, tarjeta_clima, panel_ubicacion,
                             tarjeta_calidad_aire, consulta_medicamento
supabase/
  schema.sql                 tablas, vista, triggers, RLS y permisos
  seed.sql                   datos de prueba (centros, servicios, farmacias y turnos)
test/                        unitarias y de widgets (fakes y MockClient)
integration_test/            end-to-end Sprint 2 (app_test), Sprint 3 y Sprint 4 (aire, voz, WhatsApp)
test_driver/                 guardan las capturas de las pruebas end-to-end
sprint3-evidencias/          capturas Android/iOS y registros del Sprint 3
sprint4-evidencias/          capturas Android/iOS, registros y salidas de pruebas del Sprint 4
sprint4-documento/           documento final indexado de los Sprints 1 a 4 (Word y PDF)
```

## Modelo de datos

```
auth.users 1──1 perfiles 1──N favoritos N──1 centros_salud N──M servicios
                         1──N recordatorios N──1 centros_salud   (centro_servicios)
farmacias 1──N turnos_farmacia                                   (Sprint 3)
farmacias.whatsapp (opcional, check ^591[67][0-9]{7}$)           (Sprint 4)
```

- `perfiles`: se crea solo al registrarse (trigger sobre `auth.users`).
- `favoritos` y `recordatorios`: columna `activo` para la **baja lógica**; no existe política
  DELETE, así que nadie puede borrar filas físicamente desde la app.
- `centros_salud`, `servicios`, `centro_servicios`, `farmacias`, `turnos_farmacia`: catálogos
  de solo lectura para usuarios autenticados (el rol `anon` no ve nada). El administrador los
  gestionará desde un panel web en una etapa posterior.
- Un turno de farmacia dura 24 horas: empieza el día `fecha` a las 08:00 y termina al día
  siguiente a las 08:00.
