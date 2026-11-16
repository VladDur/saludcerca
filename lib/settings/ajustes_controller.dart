import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de accesibilidad y apariencia (HU-05 y modo oscuro HU-06).
/// Se guardan en el teléfono con SharedPreferences, así se mantienen
/// al cerrar y volver a abrir la app.
class AjustesController extends ChangeNotifier {
  static const kTextoGrande = 'ajustes.texto_grande';
  static const kAltoContraste = 'ajustes.alto_contraste';
  static const kModoTema = 'ajustes.modo_tema';

  /// Factor aplicado sobre el tamaño de texto del sistema.
  static const escalaTextoGrande = 1.3;

  final SharedPreferences _prefs;

  AjustesController(this._prefs)
      : _textoGrande = _prefs.getBool(kTextoGrande) ?? false,
        _altoContraste = _prefs.getBool(kAltoContraste) ?? false,
        _modoTema = ThemeMode.values.firstWhere(
          (m) => m.name == _prefs.getString(kModoTema),
          orElse: () => ThemeMode.system,
        );

  static Future<AjustesController> cargar() async =>
      AjustesController(await SharedPreferences.getInstance());

  bool _textoGrande;
  bool _altoContraste;
  ThemeMode _modoTema;

  bool get textoGrande => _textoGrande;
  bool get altoContraste => _altoContraste;
  ThemeMode get modoTema => _modoTema;

  Future<void> cambiarTextoGrande(bool valor) async {
    _textoGrande = valor;
    notifyListeners();
    await _prefs.setBool(kTextoGrande, valor);
  }

  Future<void> cambiarAltoContraste(bool valor) async {
    _altoContraste = valor;
    notifyListeners();
    await _prefs.setBool(kAltoContraste, valor);
  }

  Future<void> cambiarModoTema(ThemeMode modo) async {
    _modoTema = modo;
    notifyListeners();
    await _prefs.setString(kModoTema, modo.name);
  }
}
