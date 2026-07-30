import 'package:supabase_flutter/supabase_flutter.dart';
import 'pin_hash.dart';
import 'enviar_notificacion.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://dgdmvwyzwvqunkpamfnk.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnZG12d3l6d3ZxdW5rcGFtZm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1MTM2MjQsImV4cCI6MjA5NjA4OTYyNH0.beAI86z6P_TvpUK6oBRUaesLZbn5id0BzOHQDtMDw_E',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  // ─── AUTH HELPERS ───────────────────────────────────────
  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => currentUser?.id;
  static bool get haySesion => currentUser != null;

  static Future<AuthResponse> registrarse({
    required String email,
    required String password,
    required String nombre,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
      data: {'nombre': nombre},
    );
  }

  static Future<AuthResponse> iniciarSesion({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> cerrarSesion() => client.auth.signOut();

  // ─── CACHÉ DE PAREJA_ID ─────────────────────────────────
  static String? parejaId; // se llena una sola vez al iniciar sesión

  static Future<void> cargarParejaId() async {
    if (currentUserId == null) return;
    final data = await client
        .from('usuarios')
        .select('pareja_id')
        .eq('id', currentUserId!)
        .maybeSingle();
    parejaId = data?['pareja_id'] as String?;
  }

  /// Regresa el pareja_id del usuario actual, o null si aún no tiene pareja
  static Future<String?> obtenerParejaId() async {
    if (currentUserId == null) return null;
    final data = await client
        .from('usuarios')
        .select('pareja_id')
        .eq('id', currentUserId!)
        .maybeSingle();
    return data?['pareja_id'] as String?;
  }

  static Future<String> crearPareja() async {
    final res = await client.rpc('crear_pareja');
    return res as String;
  }

  static Future<String> unirseAPareja(String codigo) async {
    final res = await client.rpc('unirse_pareja', params: {'codigo': codigo});
    return res as String;
  }

  // ─── PIN LOCAL ──────────────────────────────────────────
  static Future<String?> obtenerPinLocal() async {
    if (currentUserId == null) return null;
    final data = await client
        .from('usuarios')
        .select('pin_local')
        .eq('id', currentUserId!)
        .maybeSingle();
    return data?['pin_local'] as String?;
  }

  static Future<void> guardarPinLocal(String pin) async {
    if (currentUserId == null) return;
    await client
        .from('usuarios')
        .update({'pin_local': PinHash.hashear(pin)})
        .eq('id', currentUserId!);
  }
  // ─── ESTADOS DE ÁNIMO ───────────────────────────────────
  static Future<void> guardarEstado(String emoji, String texto) async {
    if (currentUserId == null) return;

    // Obtener el nombre del usuario actual
    final userData = await client
        .from('usuarios')
        .select('nombre')
        .eq('id', currentUserId!)
        .maybeSingle();
    final nombre = userData?['nombre'] as String? ?? 'Tu pareja';

    await client.from('usuarios').update({
      'estado_emoji': emoji,
      'estado_texto': texto,
      'estado_actualizado_en': DateTime.now().toIso8601String(),
    }).eq('id', currentUserId!);

    // Notificar solo si hay un estado real (no al limpiar)
    if (emoji.isNotEmpty && texto.isNotEmpty) {
      await EnviarNotificacion.enviarAPareja(
        '$nombre cambió su estado $emoji',
        'Dice que está: $texto',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> obtenerEstadosPareja() async {
    if (parejaId == null) return [];
    return await client
        .from('usuarios')
        .select('id, nombre, estado_emoji, estado_texto, estado_actualizado_en')
        .eq('pareja_id', parejaId!);
  }

  // ─── OPTIMIZACIÓN DE IMÁGENES ────────────────────────
  static String imagenOptimizada(
    String? url, {
    int width = 400,
    int quality = 75,
    String resize = 'origin',
  }) {
    if (url == null || url.isEmpty) return '';
    return url; // devuelve la URL original sin transformar
  }
}
