import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Convierte cualquier excepción en un mensaje claro en español.
String mensajeError(Object error) {
  if (error is AuthException) {
    // Primero los fallos de red: su texto incluye la URL
    // (".../token?grant_type=password") y no deben confundirse con la clave.
    if (error is AuthRetryableFetchException ||
        (error.statusCode == null && _pareceRed(error.message))) {
      return _sinConexion;
    }
    final m = error.message.toLowerCase();
    if (m.contains('invalid login')) return 'Correo o contraseña incorrectos.';
    if (m.contains('email not confirmed')) {
      return 'Debes confirmar tu correo antes de ingresar. Revisa tu bandeja de entrada.';
    }
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Ya existe una cuenta con ese correo.';
    }
    if (m.contains('rate limit')) {
      return 'Demasiados intentos. Espera unos minutos y vuelve a intentar.';
    }
    if (error is AuthWeakPasswordException ||
        m.contains('password should be')) {
      return 'La contraseña no cumple los requisitos.';
    }
    if (m.contains('sesión expirada') || m.contains('jwt')) {
      return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    }
    return 'No se pudo completar: ${error.message}';
  }
  if (error is PostgrestException) {
    if (error.code == '23505') return 'Ese registro ya existe.';
    if (error.code == '42501') return 'No tienes permiso para esta acción.';
    if (error.code == '23514') return 'Algún dato no es válido.';
    return 'Error de la base de datos (${error.code ?? 'desconocido'}).';
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error.toString().contains('SocketException') ||
      error.toString().contains('ClientException')) {
    return _sinConexion;
  }
  return 'Ocurrió un error inesperado. Intenta otra vez.';
}

const _sinConexion =
    'Sin conexión a internet. Revisa tu red e intenta otra vez.';

bool _pareceRed(String m) {
  final t = m.toLowerCase();
  return t.contains('socket') ||
      t.contains('failed host lookup') ||
      t.contains('clientexception') ||
      t.contains('connection');
}
