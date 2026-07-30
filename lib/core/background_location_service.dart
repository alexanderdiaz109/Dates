import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

@pragma('vm:entry-point')
class BackgroundLocationService {
  BackgroundLocationService._();

  static Future<void> inicializar() async {
    // Crear el canal de notificación ANTES de configurar el servicio.
    // Si el canal no existe cuando Android llama startForeground(), la app crashea.
    const channel = AndroidNotificationChannel(
      'ubicacion_en_vivo',
      'Ubicación en Vivo',
      description: 'Notificación persistente mientras compartes tu ubicación',
      importance: Importance.low,
    );
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'ubicacion_en_vivo',
        initialNotificationTitle: 'Nuestro Espacio',
        initialNotificationContent: 'Compartiendo tu ubicación en vivo',
        foregroundServiceNotificationId: 999,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<void> iniciarServicio() async {
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) service.startService();
  }

  static Future<void> detenerServicio() async {
    final service = FlutterBackgroundService();
    service.invoke('detener');
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('detener').listen((event) {
        service.stopSelf();
      });
    }

    await SupabaseConfig.initialize();
    final supabase = Supabase.instance.client;

    Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );

        final userId = supabase.auth.currentUser?.id;
        if (userId == null) return;

        final data = await supabase
            .from('usuarios')
            .select('pareja_id')
            .eq('id', userId)
            .maybeSingle();
        final parejaId = data?['pareja_id'];
        if (parejaId == null) return;

        await supabase.from('ubicaciones').upsert({
          'user_id': userId, // Mantenemos la columna vieja para evitar el constraint NOT NULL
          'usuario_id': userId,
          'pareja_id': parejaId,
          'latitud': pos.latitude,
          'longitud': pos.longitude,
          'actualizado_en': DateTime.now().toIso8601String(),
        }, onConflict: 'usuario_id');

        // ignore: avoid_print
        print('✅ BackgroundLocationService: ubicación guardada para $userId');
      } catch (e) {
        // ignore: avoid_print
        print('❌ BackgroundLocationService ERROR: $e');
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }
}
