import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'core/background_location_service.dart';
import 'core/supabase_config.dart';
import 'core/notificaciones_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_pareja_screen.dart';
import 'screens/crear_pin_screen.dart';
import 'screens/login_pin_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await SupabaseConfig.initialize();
  await NotificacionesService.inicializar();
  await BackgroundLocationService.inicializar();
  runApp(const MyApp());
}

final ValueNotifier<String> appThemeNotifier = ValueNotifier('classic');
StreamSubscription<List<Map<String, dynamic>>>? _themeSubscription;

void _iniciarEscuchaTema(String parejaId) {
  _themeSubscription?.cancel();
  _themeSubscription = Supabase.instance.client
      .from('parejas')
      .stream(primaryKey: ['id'])
      .eq('id', parejaId)
      .listen((data) {
    if (data.isNotEmpty) {
      appThemeNotifier.value = data.first['tema'] as String? ?? 'classic';
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Nuestro Espacio',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getTheme(themeMode),
          home: const AuthGate(),
        );
      },
    );
  }
}

// ─── AUTH GATE ────────────────────────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        // Sin sesión → pantalla de login
        if (session == null) {
          _themeSubscription?.cancel();
          return const LoginScreen();
        }

        // Hay sesión → verificar si ya tiene pareja vinculada
        return FutureBuilder<String?>(
          future: SupabaseConfig.obtenerParejaId(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surface,
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            // Sin pareja → onboarding
            if (snap.data == null) {
              return const OnboardingParejaScreen();
            }

            SupabaseConfig.parejaId = snap.data;
            _iniciarEscuchaTema(snap.data!);

            // Tiene pareja → verificar si ya tiene PIN
            return FutureBuilder<String?>(
              future: SupabaseConfig.obtenerPinLocal(),
              builder: (context, pinSnap) {
                if (pinSnap.connectionState != ConnectionState.done) {
                  return Scaffold(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    body: const Center(child: CircularProgressIndicator()),
                  );
                }
                // Sin PIN → crear PIN por primera vez
                return pinSnap.data == null
                    ? const CrearPinScreen()
                    : const LoginPinScreen();
              },
            );
          },
        );
      },
    );
  }
}

