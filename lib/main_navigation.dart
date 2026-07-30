import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/enviar_notificacion.dart';
import 'core/notificaciones_service.dart';
import 'core/supabase_config.dart';
import 'screens/citas_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/muro_notas_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/ruleta_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _mostrarCorazon = false;

  String? _fotoUrl;
  StreamSubscription<List<Map<String, dynamic>>>? _fotoSub;

  @override
  void initState() {
    super.initState();
    _iniciarStreamFoto();
  }

  void _iniciarStreamFoto() {
    final parejaId = SupabaseConfig.parejaId;
    if (parejaId == null) return;
    _fotoSub = Supabase.instance.client
        .from('parejas')
        .stream(primaryKey: ['id'])
        .eq('id', parejaId)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        setState(() => _fotoUrl = data.first['foto_url'] as String?);
      }
    });
  }

  @override
  void dispose() {
    _fotoSub?.cancel();
    super.dispose();
  }

  static const List<Widget> _pages = [
    DashboardScreen(),
    CitasScreen(),
    MuroNotasScreen(),
    RuletaScreen(),
    PerfilScreen(),
  ];

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Función universal: envía a TODOS los dispositivos excepto el propio
  Future<void> _enviarTeExtrano() async {
    if (_mostrarCorazon) return;

    setState(() => _mostrarCorazon = true);

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enviando latido... ❤️'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await EnviarNotificacion.enviarAPareja(
        '¡Te extraño, mi Vida! ❤️',
        'Tu pareja está pensando en ti ahora mismo 💕',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Latido enviado! ❤️'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _mostrarCorazon = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text(
              'NUESTRO ESPACIO',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 18),
            ),
            centerTitle: true,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: InkWell(
                  onTap: () => _onTap(4),
                  borderRadius: BorderRadius.circular(50),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFBDC3C7),
                    backgroundImage: _fotoUrl != null
                        ? CachedNetworkImageProvider(
                            SupabaseConfig.imagenOptimizada(_fotoUrl, width: 120, quality: 80, resize: 'cover'))
                        : null,
                    child: _fotoUrl == null
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          body: _pages[_selectedIndex],
          floatingActionButton: FloatingActionButton(
            onPressed: _enviarTeExtrano,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: const CircleBorder(),
            child: const Icon(Icons.favorite, size: 28),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            elevation: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.home_rounded,
                    color: _selectedIndex == 0 ? Theme.of(context).colorScheme.primary : const Color(0xFF95A5A6),
                  ),
                  onPressed: () => _onTap(0),
                ),
                IconButton(
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    color: _selectedIndex == 1 ? Theme.of(context).colorScheme.primary : const Color(0xFF95A5A6),
                  ),
                  onPressed: () => _onTap(1),
                ),
                const SizedBox(width: 40),
                IconButton(
                  icon: Icon(
                    Icons.note_alt_rounded,
                    color: _selectedIndex == 2 ? Theme.of(context).colorScheme.primary : const Color(0xFF95A5A6),
                  ),
                  onPressed: () => _onTap(2),
                ),
                IconButton(
                  icon: Icon(
                    Icons.casino_rounded,
                    color: _selectedIndex == 3 ? Theme.of(context).colorScheme.primary : const Color(0xFF95A5A6),
                  ),
                  onPressed: () => _onTap(3),
                ),
              ],
            ),
          ),
        ),

        // CAPA SUPERIOR: LA ANIMACIÓN DEL CORAZÓN
        if (_mostrarCorazon)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.white.withAlpha((0.6 * 255).toInt()),
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, valor, child) {
                      return Transform.scale(
                        scale: valor * 2.5,
                        child: Opacity(
                          opacity: (1.0 - (valor > 0.8 ? (valor - 0.8) * 5 : 0.0)).clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary, size: 100),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
