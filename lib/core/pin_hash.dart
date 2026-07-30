import 'dart:convert';
import 'package:crypto/crypto.dart';

class PinHash {
  PinHash._();

  /// Convierte un PIN en texto plano a su hash SHA-256 (irreversible)
  static String hashear(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compara un PIN ingresado contra el hash guardado
  static bool verificar(String pinIngresado, String hashGuardado) {
    return hashear(pinIngresado) == hashGuardado;
  }
}
