# SaludCerca · Sprint 2 (Flutter + Supabase, rol USUARIO)

App móvil híbrida para encontrar centros de salud en La Paz y El Alto.
Una sola base de código Flutter genera la app de **Android (APK)** y la de **iOS**.
El backend es **Supabase** (PostgreSQL + Auth + Row Level Security).

## Qué incluye este incremento

| Módulo | Detalle |
|---|---|
| Autenticación | Registro, inicio y cierre de sesión con correo y contraseña (Supabase Auth). La sesión queda guardada al reabrir la app. Las pantallas principales solo se ven con sesión iniciada (`AuthGate`). |
| Base de datos | 6 tablas + 1 vista, relaciones 1‑1, 1‑N y N‑M, políticas RLS (cada usuario solo ve sus datos), triggers y datos de prueba. Scripts en `supabase/`. |
| Consultas dinámicas | Lista de centros desde Supabase con búsqueda por nombre o zona y filtros por ciudad, tipo, emergencias y "abiertos ahora". Distancia calculada con Haversine. |
| CRUD | **Recordatorios** (crear, ver, editar, eliminar con baja lógica), **Favoritos** (guardar con nota, editar nota, quitar con baja lógica) y **Perfil** (ver y editar datos). Formularios validados y mensajes de confirmación/error. |
| HU‑06 Accesibilidad | En la pestaña **Perfil**: *Texto grande* (×1,3 sobre el tamaño del sistema) y *Alto contraste*. Se aplican en todas las pantallas y se mantienen al cerrar y abrir la app. Todos los botones miden al menos 48 dp (Android) / 44 pt (iOS). |
| HU nueva: Modo oscuro | En **Perfil → Tema**: Claro, Oscuro o Sistema. Persistente. Se combina con alto contraste. |

## Requisitos

- Flutter 3.x estable (probado con Flutter 3.47.9 / Dart 3.13.7)
- Android Studio con un emulador (probado en Pixel 9, Android 17) o un teléfono Android
- Xcode con simulador iOS (probado en iPhone 17, iOS 26.5) — solo en macOS
- Un proyecto de Supabase

## Instalación paso a paso

### 1. Base de datos (una sola vez)

1. Entra a <https://supabase.com/dashboard> y abre el proyecto **SaludCerca**.
2. Ve a **SQL Editor → New query**, pega el contenido de `supabase/schema.sql` y pulsa **Run**.
3. Repite con `supabase/seed.sql` (carga 10 centros y 16 servicios de prueba).
4. Opcional para pruebas: en **Authentication → Sign In / Providers → Email** puedes
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
diseño; la protección de los datos la dan las políticas RLS.

### 3. Ejecutar

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

Generar el APK de Android:

```bash
flutter build apk --release --dart-define-from-file=env.json
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.
Para iOS: `flutter build ios --dart-define-from-file=env.json` (requiere Xcode y firma).

### 4. Pruebas y análisis

```bash
flutter analyze   # análisis estático
flutter test      # 26 pruebas unitarias y de widgets (sin internet, repositorios falsos)
```

Prueba **end-to-end contra Supabase real** (login, consultas, CRUD, RLS, HU‑06, modo oscuro),
que además guarda las capturas en `sprint2-evidencias/`. Requiere `TEST_EMAIL` y
`TEST_PASSWORD` en `env.json` y un emulador o simulador abierto:

```bash
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  --dart-define-from-file=env.json -d <id-del-dispositivo>
```

## URLs y credenciales de prueba

| Dato | Valor |
|---|---|
| Panel de Supabase | <https://supabase.com/dashboard> → proyecto **SaludCerca** |
| URL de la API | `SUPABASE_URL` en `env.json` (se entrega aparte, no se sube a git) |
| Usuario de prueba | `vladi@saludcerca.app` |
| Contraseña de prueba | `Prueba123` |

También puedes crear tu propia cuenta desde la pantalla **Crear una cuenta**.

## Estructura del proyecto

```
lib/
  main.dart                  arranque: carga ajustes, inicializa Supabase
  app.dart                   MaterialApp, temas, texto grande y AuthGate
  config/env.dart            URL y anon key (desde --dart-define)
  core/                      validadores, mensajes de error, AppScope (inyección)
  data/repositorios.dart     interfaces de acceso a datos
  data/supabase/             implementación con Supabase
  models/                    centro_salud, perfil, favorito, recordatorio
  settings/                  AjustesController (HU‑06 y modo oscuro, persistente)
  screens/                   auth (login, registro), shell, centros, detalle,
                             favoritos, recordatorios, formulario, perfil
  theme/app_theme.dart       4 temas: claro, oscuro, alto contraste claro/oscuro
  widgets/                   tarjetas, etiquetas, mensajes
supabase/
  schema.sql                 tablas, vista, triggers, RLS y permisos
  seed.sql                   datos de prueba
test/                        pruebas unitarias y de widgets (repositorios falsos)
integration_test/            prueba end-to-end contra Supabase (Android e iOS)
test_driver/                 guarda las capturas de la prueba end-to-end
sprint2-evidencias/          capturas Android/iOS y salidas de test/analyze
```

## Modelo de datos

```
auth.users 1──1 perfiles 1──N favoritos N──1 centros_salud N──M servicios
                         1──N recordatorios N──1 centros_salud   (centro_servicios)
```

- `perfiles`: se crea solo al registrarse (trigger sobre `auth.users`).
- `favoritos` y `recordatorios`: columna `activo` para la **baja lógica**; no existe política
  DELETE, así que nadie puede borrar filas físicamente desde la app.
- `centros_salud`, `servicios`, `centro_servicios`: catálogo de solo lectura para usuarios
  autenticados. La vista `v_centros` (con `security_invoker`) junta cada centro con sus servicios.
