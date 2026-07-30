import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationService {
  LocationService._();
  static final _supabase = Supabase.instance.client;

  static Timer? _timer;
  static StreamSubscription<List<Map<String, dynamic>>>? _sub;

  /// Pide permisos y arranca el envío periódico de mi ubicación.
  /// onMiUbicacion y onUbicacionPareja son callbacks para actualizar la UI.
  static Future<bool> iniciar({
    required void Function(LatLng) onMiUbicacion,
    required void Function(LatLng) onUbicacionPareja,
    Duration intervalo = const Duration(seconds: 30),
  }) async {
    final servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) return false;

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) return false;
    }
    if (permiso == LocationPermission.deniedForever) return false;

    await _enviarUbicacionActual(onMiUbicacion);

    _timer?.cancel();
    _timer = Timer.periodic(intervalo, (_) => _enviarUbicacionActual(onMiUbicacion));

    _escucharPareja(onUbicacionPareja);
    return true;
  }

  static Future<void> _enviarUbicacionActual(void Function(LatLng) onMiUbicacion) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      onMiUbicacion(LatLng(pos.latitude, pos.longitude));

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('usuarios')
          .select('pareja_id')
          .eq('id', userId)
          .maybeSingle();
      final parejaId = data?['pareja_id'];
      if (parejaId == null) return;

      await _supabase.from('ubicaciones').upsert({
        'user_id': userId, // Mantenemos la columna vieja para evitar el constraint NOT NULL
        'usuario_id': userId,
        'pareja_id': parejaId,
        'latitud': pos.latitude,
        'longitud': pos.longitude,
        'actualizado_en': DateTime.now().toIso8601String(),
      }, onConflict: 'usuario_id');
    } catch (_) {}
  }

  static void _escucharPareja(void Function(LatLng) onUbicacionPareja) {
    final miUserId = _supabase.auth.currentUser?.id;
    _sub?.cancel();
    _sub = _supabase
        .from('ubicaciones')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      for (final row in rows) {
        final usuarioIdFila = row['usuario_id'];
        // ignoramos filas sin dueño y evitamos mostrarnos a nosotros mismos como "pareja"
        if (usuarioIdFila != null &&
            usuarioIdFila != miUserId &&
            row['latitud'] != null &&
            row['longitud'] != null) {
          onUbicacionPareja(LatLng(
            (row['latitud'] as num).toDouble(),
            (row['longitud'] as num).toDouble(),
          ));
        }
      }
    });
  }

  /// Devuelve fecha/hora de última actualización de mi pareja (o null)
  static Future<DateTime?> ultimaActualizacionPareja() async {
    final miUserId = _supabase.auth.currentUser?.id;
    final rows = await _supabase.from('ubicaciones').select('usuario_id, actualizado_en');
    for (final row in rows) {
      if (row['usuario_id'] != miUserId && row['actualizado_en'] != null) {
        return DateTime.tryParse(row['actualizado_en']);
      }
    }
    return null;
  }

  static void detener() {
    _timer?.cancel();
    _sub?.cancel();
    _timer = null;
    _sub = null;
  }
}
