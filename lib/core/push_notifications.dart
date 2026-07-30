import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class PushNotificationService {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;

  static Future<void> initialize() async {
    // 1. Pedir permiso al usuario (necesario en Android 13+ y iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Obtener el token de este celular
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _guardarToken(token);
      }

      // 3. Escuchar si el token se actualiza (por seguridad de Firebase)
      _firebaseMessaging.onTokenRefresh.listen(_guardarToken);
    }
  }

  static Future<void> _guardarToken(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return; // sin sesión, no hay a quién asociar el token

      final data = await _supabase
          .from('usuarios')
          .select('pareja_id')
          .eq('id', userId)
          .maybeSingle();
      final parejaId = data?['pareja_id'];
      if (parejaId == null) return; // sin pareja vinculada aún, no guardamos

      await _supabase.from('dispositivos').upsert({
        'fcm_token': token,
        'usuario_id': userId,
        'pareja_id': parejaId,
        'creado_en': DateTime.now().toIso8601String(),
        'actualizado_en': DateTime.now().toIso8601String(),
      }, onConflict: 'fcm_token');
    } catch (e) {
      print('Error al guardar token FCM: $e');
    }
  }
}
