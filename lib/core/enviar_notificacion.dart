import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnviarNotificacion {
  static final _supabase = Supabase.instance.client;

  // ── Enviar latido del corazón a un token específico ─────────────
  static Future<bool> latido(String tokenDestino, {String nombreEmisor = 'Holaaa'}) async {
    try {
      final res = await _supabase.functions.invoke('enviar-notificacion', body: {
        'modo': 'token',
        'token': tokenDestino,
        'titulo': '¡Te extraño, mi Vida! ❤️',
        'cuerpo': '...',
      });
      debugPrint('✅ Latido enviado: ${res.data}');
      return true;
    } catch (e) {
      debugPrint('❌ Error crítico al enviar latido: $e');
      return false;
    }
  }

  // ── Enviar a TODOS los dispositivos registrados ──────────────────
  static Future<void> enviarATodos(String titulo, String cuerpo) async {
    try {
      final res = await _supabase.functions.invoke('enviar-notificacion', body: {
        'modo': 'todos',
        'titulo': titulo,
        'cuerpo': cuerpo,
      });
      debugPrint('✅ Notificación masiva completada: ${res.data}');
    } catch (e) {
      debugPrint('❌ Error en enviarATodos: $e');
    }
  }

  // ── Enviar a la PAREJA ───────────────────────────────────────────
  static Future<void> enviarAPareja(String titulo, String cuerpo) async {
    final usuarioId = _supabase.auth.currentUser?.id;
    if (usuarioId == null) return;

    try {
      final res = await _supabase.functions.invoke('enviar-notificacion', body: {
        'modo': 'pareja',
        'usuarioId': usuarioId,
        'titulo': titulo,
        'cuerpo': cuerpo,
      });
      debugPrint('✅ Notificación a pareja enviada: ${res.data}');
    } catch (e) {
      debugPrint('❌ Error en enviarAPareja: $e');
    }
  }
}
