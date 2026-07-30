import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Canal de notificaciones de Android ─────────────────────────────
const AndroidNotificationChannel _canal = AndroidNotificationChannel(
  'latidos',                     // ID (mismo que usamos en enviar_notificacion.dart)
  'Latidos del corazón',         // Nombre visible
  description: 'Notificaciones de tu pareja',
  importance: Importance.max,
  playSound: true,
);

// Canal para el servicio de ubicación en segundo plano
const AndroidNotificationChannel _canalUbicacion = AndroidNotificationChannel(
  'ubicacion_en_vivo',
  'Ubicación en vivo',
  description: 'Servicio de compartir ubicación con tu pareja',
  importance: Importance.low,
  playSound: false,
);

final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

// ── Handler para mensajes en BACKGROUND / app cerrada ──────────────
// DEBE ser una función de nivel superior (no método de clase)
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  // Firebase ya está inicializado por el framework cuando llega aquí
  debugPrint('📩 Mensaje en background: ${message.notification?.title}');
}

class NotificacionesService {
  /// Token FCM de este celular. Se llena al inicializar.
  static String? miToken;

  static Future<void> inicializar() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Pedir permiso (Android 13+)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('⚠️ Permiso de notificaciones denegado.');
        return;
      }

      // 2. Crear los canales de Android
      final androidPlugin = _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_canal);
      await androidPlugin?.createNotificationChannel(_canalUbicacion);

      // 3. Inicializar flutter_local_notifications
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notificacion'),
      );
      await _localNotif.initialize(initSettings);

      // 4. Registrar el handler de background
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

      // 5. Mostrar notificación local cuando la app está en FOREGROUND
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notif = message.notification;
        final android = message.notification?.android;
        if (notif != null && android != null) {
          _localNotif.show(
            notif.hashCode,
            notif.title,
            notif.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _canal.id,
                _canal.name,
                channelDescription: _canal.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: 'ic_notificacion',
                color: const Color(0xFFFF6A88),
              ),
            ),
          );
        }
      });

      // 6. Forzar invalidación del token anterior y obtener uno nuevo
      try {
        await messaging.deleteToken();
      } catch (e) {
        debugPrint('⚠️ No se pudo eliminar el token anterior: $e');
      }
      final token = await messaging.getToken();
      if (token != null) {
        miToken = token; // Guardamos para saber cuál es "este" celular
        debugPrint('🔑 FCM Token: $token');
        await _guardarToken(token);
      }
      messaging.onTokenRefresh.listen((t) {
        miToken = t;
        _guardarToken(t);
      });

      debugPrint('✅ NotificacionesService inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error al inicializar notificaciones: $e');
    }
  }

  static Future<void> _guardarToken(String token) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return; // sin sesión, no guardamos

      final data = await client
          .from('usuarios')
          .select('pareja_id')
          .eq('id', userId)
          .maybeSingle();
      final parejaId = data?['pareja_id'];
      if (parejaId == null) return; // sin pareja vinculada aún

      await client.from('dispositivos').upsert({
        'fcm_token': token,
        'usuario_id': userId,
        'pareja_id': parejaId,
        'actualizado_en': DateTime.now().toIso8601String(),
      }, onConflict: 'usuario_id');
      debugPrint('✅ Token guardado en Supabase');
    } catch (e) {
      debugPrint('❌ Error guardando token: $e');
    }
  }
}
