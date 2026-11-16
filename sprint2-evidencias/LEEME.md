# Evidencias del Sprint 2 · SaludCerca

Generadas el 16/11/2026 contra el proyecto real de Supabase.

| Archivo | Qué demuestra | Sección del documento |
|---|---|---|
| `flutter_version.txt`, `dispositivos.txt` | Entorno: Flutter, emulador Android (Pixel 9, Android 17) y simulador iOS (iPhone 17, iOS 26.5) | 3.1 |
| `flutter_analyze.txt` | Análisis estático sin problemas | 9 |
| `flutter_test.txt` | 26 pruebas unitarias y de widgets en verde (validaciones, CRUD, auth, HU‑06, botones ≥ 48 dp / 44 pt, contraste) | 9.2, 9.4, 9.5 |
| `prueba_e2e_ios.txt`, `prueba_e2e_android.txt` | Prueba end-to-end contra Supabase aprobada en ambas plataformas | 9.3 a 9.7 |
| `prueba_rls_sin_sesion.txt` | Sin sesión (rol anon) la API rechaza todas las tablas | 7.8, 9.6 |

La prueba end-to-end también comprobó, con sesión iniciada: que el usuario solo ve sus propios
favoritos, que no puede crear recordatorios a nombre de otro usuario, que el borrado físico
(DELETE) está prohibido y que el recordatorio eliminado queda en la base con `activo = false`.

## Capturas (cada una existe en `_android.png` y `_ios.png`)

| N.º | Pantalla | Sección |
|---|---|---|
| 01–03 | Login, validación de campos vacíos, error de credenciales | 7.4, 6.5, 6.6 |
| 04–06 | Lista de centros desde Supabase, filtros (El Alto + Emergencias), búsqueda | 5.3, 5.4 |
| 07 | Detalle del centro | 8.1 |
| 08–10 | Favorito: formulario con nota, confirmación, lista de favoritos | 6.1, 6.2 |
| 11–13 | Recordatorio: validación, formulario, creado | 6.1, 6.5, 6.6 |
| 14 | Recordatorio editado | 6.3 |
| 15–16 | Confirmar eliminación y baja lógica | 6.4 |
| 17–19 | Perfil: datos, validación de teléfono, guardado | 6.2, 6.3, 7.6 |
| 20–21 | HU‑06 Texto grande (Perfil y Centros) | HU‑06 |
| 22–23 | HU‑06 Alto contraste (Perfil y Centros) | HU‑06 |
| 24 | Modo oscuro + alto contraste | HU nueva |
| 25–27 | Modo oscuro (Perfil, Centros, Favoritos) | HU nueva |
| 28 | Confirmación de cierre de sesión | 7.4 |
