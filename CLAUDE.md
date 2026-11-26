# CLAUDE.md · Contexto del proyecto SaludCerca

Guía para cualquier sesión de Claude (o persona) que retome este repositorio.
**Responde siempre en español.**

## 1. Qué es

**SaludCerca** es una app móvil para encontrar centros de salud (y, más adelante, farmacias
de turno) en **La Paz y El Alto, Bolivia**. Está pensada sobre todo para adultos mayores y
sus familias, con textos y botones grandes.

- Es el proyecto académico de **Aplicaciones Móviles I (SIS‑0180), UPDS**.
- Usa **Flutter**: una sola base de código genera la app de **Android y la de iOS a la vez**.
  No hay que priorizar una plataforma sobre la otra.
- El backend es **Supabase** (PostgreSQL + Auth + RLS).
- Se trabaja con Scrum. Cada sprint entrega un documento técnico (APA 7) siguiendo la guía de
  la materia, más un README y un zip del código.

## 2. Alcance y roles de la app

- **Solo existe el rol USUARIO** dentro de la app móvil.
- El rol **ADMINISTRADOR** (gestionar centros, farmacias y turnos) queda para una **etapa
  posterior como panel web**. No se implementa en la app.
- Mientras tanto, los catálogos (centros, servicios) se cargan por SQL (`supabase/seed.sql`).

## 3. Equipo

| Rol Scrum | Persona |
|---|---|
| Product Owner y docente | Lic. Rosalia Lopez Montalvo |
| Scrum Master | Ysrael Jimy Quispe Llusco |
| Desarrolladores | Antoneitte Amelia Blanco Quispe, Vladimir Durán Claros, Ysrael Jimy Quispe Llusco, Javier Amador Matilla Valencia |

Vladimir Durán Claros es quien trabaja en este repositorio con Claude.

## 4. Product Backlog vigente (20 HU, numeración del Sprint 2)

En el Sprint 2 hubo cambios en el backlog:
- Se **retiró la antigua HU‑01** ("configurar el entorno Flutter") porque no aporta valor al usuario final.
- **Se renumeró:** las antiguas HU‑02 a HU‑06 pasaron a ser HU‑01 a HU‑05. De HU‑07 en adelante se conserva el número.
- Se **agregó HU‑06, modo oscuro**.
- **HU‑03 (farmacias de turno)** se reprogramó para el Sprint 3.

| HU | Historia (resumen) | Prioridad | Pts | Sprint | Estado |
|---|---|---|---|---|---|
| HU‑01 | Pantalla de bienvenida e inicio de sesión | Must | 3 | 1 | Hecho |
| HU‑02 | Navegación por pestañas (Centros, Favoritos, Recordatorios, Perfil) | Must | 3 | 2 | Hecho |
| HU‑03 | Farmacias de turno | Must | 5 | 3 | Hecho |
| HU‑04 | Detalle de un centro de salud | Must | 3 | 1 | Hecho |
| HU‑05 | **Accesibilidad**: texto grande y alto contraste, botones amplios | Should | 3 | 2 | Hecho |
| HU‑06 | **Modo oscuro**: claro / oscuro / sistema (nueva) | Should | 3 | 2 | Hecho |
| HU‑07 | Registro e inicio de sesión con correo | Must | 5 | 2 | Hecho |
| HU‑08 | Perfil básico (datos, ciudad, contacto de emergencia) | Must | 5 | 2 | Hecho |
| HU‑09 | Buscar y filtrar centros (tipo, ciudad, emergencias) | Must | 5 | 2 | Hecho |
| HU‑10 | CRUD de recordatorios (citas, medicamentos, controles) | Must | 8 | 2 | Hecho |
| HU‑11 | Instalar en un Android y un iPhone reales | Must | 5 | 2 | Hecho (16/11/2026) |
| HU‑12 | Mapa interactivo de farmacias y centros | Must | 5 | 3 | Hecho |
| HU‑13 | Detectar la ubicación del usuario | Must | 5 | 3 | Hecho |
| HU‑14 | Alarma a la hora del medicamento | Must | 5 | 4 | Por hacer (movida al Sprint 4) |
| HU‑15 | Consejos de salud preventiva | Should | 8 | 4 | Por hacer (movida al Sprint 4) |
| HU‑16 | Farmacias de turno sin conexión | Should | 8 | 4 | Por hacer |
| HU‑17 | Pruebas unitarias y beta con adultos mayores | Must | 5 | 4 | Por hacer |
| HU‑18 | Protección de datos médicos | Must | 5 | 4 | En progreso (RLS ya aplicada) |
| HU‑19 | Documentación y video demostrativo | Must | 3 | 4 | Por hacer |
| HU‑20 | Builds de producción firmados (Android e iOS) | Must | 5 | 4 | Por hacer |

El detalle (criterios de aceptación, responsables y tareas) está en el documento del Sprint 2 y
en `sprint2-documento/SaludCerca_Tablero_Sprint2.xlsx`.

## 5. Estado de los sprints

- **Sprint 1 (terminado):** prototipo de 3 pantallas con datos en memoria (commit
  `d98fbd8`). Las evidencias están en `sprint1-evidencias/`. El prototipo **no** se modifica.
- **Sprint 2 (implementado, en la rama `sprint2`):** Supabase, autenticación, consultas
  dinámicas, CRUD con baja lógica, HU‑05 y HU‑06. 8 de 8 HU y 37 de 37 puntos (100 %). Pruebas unitarias y end-to-end en verde en
  Android e iOS. El documento técnico está en `sprint2-documento/`.
- **Sprint 3 (implementado, rama `sprint3`, entrega 23/11/2026):** consumo de APIs. HU‑03
  farmacias de turno (tablas `farmacias` y `turnos_farmacia`), HU‑13 ubicación (geolocator),
  HU‑12 mapa (flutter_map + teselas OSM, búsqueda con Nominatim) y clima con Open-Meteo.
  76 pruebas y E2E en verde en Android e iOS. Detalle técnico en `SPRINT3_NOTAS.md`,
  evidencias en `sprint3-evidencias/`, ZIP en `Entrega_Sprint3/`.

## 6. Arquitectura y carpetas

```
lib/
  main.dart                  arranque: carga ajustes e inicializa Supabase
  app.dart                   MaterialApp, 4 temas, texto grande (MediaQuery) y AuthGate
  config/env.dart            SUPABASE_URL / SUPABASE_ANON_KEY desde --dart-define
  core/app_scope.dart        InheritedWidget con las dependencias (repositorios + ajustes)
  core/validadores.dart      validaciones de formularios
  core/errores.dart          traduce excepciones a mensajes en español
  data/repositorios.dart     interfaces (Auth, Centros, Favoritos, Recordatorios, Perfil)
  data/supabase/             implementación real con supabase_flutter
  models/                    centro_salud, perfil, favorito, recordatorio
  settings/                  AjustesController (HU‑05 y HU‑06) con shared_preferences
  screens/                   auth/ (login, registro), shell (NavigationBar), centros,
                             detalle, favoritos, recordatorios, recordatorio_form, perfil
  theme/app_theme.dart       claro, oscuro y alto contraste (claro y oscuro); ColoresSalud
  widgets/                   centro_card, etiqueta_estado, fila_info, mensajes
supabase/schema.sql          tablas, vista, triggers, RLS y permisos (idempotente)
supabase/seed.sql            10 centros, 16 servicios y sus relaciones
test/                        unitarias y de widgets con repositorios falsos (test/fakes.dart)
integration_test/app_test.dart  prueba end-to-end contra Supabase real + capturas
test_driver/                 guarda las capturas en sprint2-evidencias/
```

Patrón: pantallas → interfaces de repositorio → implementación Supabase. Las pruebas cambian
la implementación por fakes. No hay paquete de estado externo: se usan `ChangeNotifier`,
`ListenableBuilder` e `InheritedWidget`.

## 7. Supabase

- Proyecto **SaludCerca**, región **us-east-1**.
- **La URL y la clave no se guardan en el repositorio.** Viven en `env.json` (está en
  `.gitignore`); `env.example.json` es la plantilla. Nunca escribas la URL real, la anon o
  publishable key, ni la contraseña de la base de datos en archivos versionados. La contraseña
  de la base de datos la guarda el usuario: no se pide.
- **Tablas:** `perfiles` (1‑1 con `auth.users`, la crea un trigger al registrarse),
  `centros_salud`, `servicios`, `centro_servicios` (N‑M), `favoritos` (con nota) y
  `recordatorios`. La vista `v_centros` (con `security_invoker`) junta cada centro con sus servicios.
- **Baja lógica:** `favoritos` y `recordatorios` tienen la columna `activo`. "Eliminar" es
  `update activo = false`. No existe política DELETE y se revocó DELETE al rol `authenticated`.
- **RLS:** cada usuario solo ve y modifica sus propias filas. Los catálogos son de solo lectura
  para usuarios autenticados. El rol `anon` no puede leer nada.
- Si cambias el esquema, edita `supabase/schema.sql` (debe seguir siendo idempotente) y
  ejecútalo en el SQL Editor.

## 8. Cómo correr, probar y compilar

```bash
flutter pub get
flutter run --dart-define-from-file=env.json          # sin esto aparece "Falta configurar Supabase"
flutter analyze
flutter test                                          # 76 pruebas, sin internet
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart --dart-define-from-file=env.json -d <id>
flutter build apk --release --dart-define-from-file=env.json
```

- `env.json` también lleva `TEST_EMAIL` y `TEST_PASSWORD` para la prueba end-to-end.
- Dispositivos usados: emulador **Pixel 9 (Android 17)** y simulador **iPhone 17 (iOS 26.5)**.
- **APK release:** `android/app/src/main/AndroidManifest.xml` **debe** declarar
  `android.permission.INTERNET`. Sin ese permiso funciona en debug pero no en el celular.
- Usuario de prueba (ya creado en Supabase): **vladi@saludcerca.app / Prueba123**.

## 9. Documentos y entregables

| Ubicación | Contenido |
|---|---|
| `sprint1-evidencias/` | Capturas y salidas del Sprint 1 |
| `sprint2-evidencias/` | 28 capturas por plataforma (`NN_nombre_android/ios.png`), salidas de test, analyze y RLS, y `LEEME.md` con el mapa captura → sección |
| `sprint2-documento/` | Documento técnico del Sprint 2 (.docx y .pdf, APA 7) y tablero .xlsx |
| `../Entrega_Sprint2/` | Zip del código (`git archive`), APK release y hojas resumen de capturas |
| `~/Downloads/Sprint_2.pdf` | Guía oficial del Sprint 2 (estructura del documento y rúbrica) |

## 10. Convenciones

- Código, comentarios, mensajes y commits **en español**. Usa nombres de dominio en español
  (`centro`, `recordatorio`, `perfil`).
- Accesibilidad obligatoria en toda pantalla nueva: los controles deben medir al menos 48 dp
  (Android) y 44 pt (iOS). Los colores se toman del tema (`Theme.of`, `ColoresSalud`), nunca
  fijos, para que funcionen en oscuro y alto contraste. Los textos deben aguantar ×1,3 sin
  desbordarse.
- Formularios con validación (`core/validadores.dart`). Los mensajes al usuario se muestran con
  `Mensajes.exito`, `Mensajes.error` y `Mensajes.confirmar`. Los errores se traducen en
  `core/errores.dart`.
- Toda acción destructiva pide confirmación y hace baja lógica.
- Antes de un commit: `flutter analyze` sin problemas y `flutter test` en verde.
- Los commits van en la rama del sprint (`sprint2`, `sprint3`…). **No hagas push sin
  aprobación explícita del usuario.**

## 11. Decisiones tomadas

- Solo rol USUARIO; el administrador será web y posterior.
- Android e iOS se trabajan a la vez, con Flutter.
- HU‑05 (accesibilidad) se implementó directamente en la app del Sprint 2, no en el prototipo
  del Sprint 1.
- HU‑06 (modo oscuro) se agregó al backlog en el Sprint 2.
- Las distancias se calculan desde un punto fijo (Plaza Murillo) con Haversine; el GPS llega
  con HU‑13.
- "Abierto ahora" se calcula en la app con `dias_atencion`, `hora_apertura` y `hora_cierre`.

## 12. Problemas ya resueltos

- **El APK no iniciaba sesión en el celular real.** Faltaba el permiso INTERNET en el
  manifest `main`; solo estaba en los manifests `debug` y `profile`. Se corrigió en el commit `215c542`.
- **Mensaje engañoso "La contraseña no cumple los requisitos".** El texto del error de red
  contiene la URL `...grant_type=password`. Ahora los errores de red se detectan primero y
  muestran "Sin conexión a internet…". Hay pruebas en `test/unidad_test.dart`.
- **Registro con un correo ya existente parecía exitoso.** Con "Confirm email" activo, Supabase
  no revela si el correo existe: devuelve un usuario con `identities` vacío. Ahora
  `SupabaseAuthRepositorio.registrar` lo detecta (`correoYaRegistrado`) y muestra "Este correo
  ya está registrado…". Hay pruebas en `test/unidad_test.dart` y `test/widget_test.dart`.
- **Pruebas E2E con ubicación:** `flutter drive` desinstala la app al terminar y se pierde el
  permiso; instala y concede antes (`xcrun simctl privacy <udid> grant location`,
  `adb shell pm grant`). En el emulador Android la posición se fija con
  `adb shell appops set com.android.shell android:mock_location allow` y
  `adb shell cmd location providers set-test-provider-location gps --location -16.51,-68.127`.
  En el simulador iOS la pantalla puede quedar congelada con `flutter drive` (capturas en
  blanco): lanzar la app de prueba directo y capturar con `xcrun simctl io screenshot` al ver
  `[CAPTURA]` en `log stream`.
- **Simulador iOS:** no se puede escribir a mano en los campos de Flutter con las
  herramientas de automatización; usa `integration_test`. En el emulador Android, `adb input`
  pierde caracteres cuando la Mac está cargada.

## 13. Pendientes

- Las ramas `sprint2` y `sprint3` ya están en `origin` (GitHub `VladDur/saludcerca`),
  subidas el 23/11/2026 con aprobación del usuario. Aún no hay pull request. Todo push
  nuevo requiere aprobación explícita.
- **Completar los datos `[COMPLETAR]` / `[CONFIRMAR]` del documento del Sprint 2**: unos 14
  datos del equipo, como las estimaciones de Planning Poker, el seguimiento y el feedback.
- **Sprint 4:** HU‑14, HU‑15, HU‑16 a HU‑20; revisar colores (feedback del Sprint 2).
