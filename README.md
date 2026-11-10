# SaludCerca · Prototipo Flutter (rol USUARIO)

Prototipo de 3 pantallas, sin base de datos (datos de ejemplo en `lib/data/`).
Android (APK) e iOS desde la misma base de código.

## Pantallas
1. **Inicio de sesión** (`login_screen.dart`): valida correo y contraseña; botón "Entrar como invitado".
2. **Inicio** (`home_screen.dart`): saludo, búsqueda por nombre o zona, filtros (Todos / Abiertos ahora / Emergencias) y lista de centros ordenados por distancia.
3. **Detalle del centro** (`detalle_centro_screen.dart`): estado, dirección, horario, teléfono, servicios y botones Llamar / Cómo llegar (avisan que llegan en una próxima versión).

## Estructura
```
lib/
  main.dart                 arranque y rutas
  models/centro_salud.dart  modelo
  data/centros_ejemplo.dart datos de ejemplo
  screens/                  las 3 pantallas
  widgets/                  centro_card, etiqueta_estado, fila_info
  theme/app_theme.dart      colores y estilos (textos grandes)
```

## Cómo ejecutarlo
```bash
flutter create --project-name saludcerca --platforms android,ios .
flutter pub get
flutter run
```
`flutter create .` solo agrega las carpetas `android/` e `ios/`; no reemplaza los archivos que ya existen.
