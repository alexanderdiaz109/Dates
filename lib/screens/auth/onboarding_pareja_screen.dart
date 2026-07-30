import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_config.dart';
import '../crear_pin_screen.dart';
import '../login_pin_screen.dart';

class OnboardingParejaScreen extends StatefulWidget {
  const OnboardingParejaScreen({super.key});

  @override
  State<OnboardingParejaScreen> createState() => _OnboardingParejaScreenState();
}

class _OnboardingParejaScreenState extends State<OnboardingParejaScreen> {
  final _codigoCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;
  String? _codigoGenerado;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _crearEspacio() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await SupabaseConfig.crearPareja();
      final parejaId = await SupabaseConfig.obtenerParejaId();
      if (parejaId == null) throw Exception('No se pudo obtener pareja_id');
      final data = await SupabaseConfig.client
          .from('parejas')
          .select('codigo_invitacion')
          .eq('id', parejaId)
          .single();
      setState(() => _codigoGenerado = data['codigo_invitacion'] as String);
    } catch (e) {
      setState(() => _error = 'No se pudo crear el espacio. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _unirse() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await SupabaseConfig.unirseAPareja(codigo);
      if (!mounted) return;

      // Revisamos si ya tiene PIN antes de decidir a dónde mandarlo
      final pin = await SupabaseConfig.obtenerPinLocal();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => pin == null ? const CrearPinScreen() : const LoginPinScreen(),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Código no válido, verifica e intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _continuar() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPinScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // ─── ÍCONO ─────────────────────────────────────
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withAlpha(20),
                  border: Border.all(color: primary.withAlpha(60), width: 2),
                ),
                child: Icon(Icons.favorite_rounded, size: 38, color: primary),
              ),
              const SizedBox(height: 20),

              Text(
                '¿Crear un espacio nuevo\no unirte a uno?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Invita a tu pareja y compartan este espacio único.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: onSurface.withAlpha(140)),
              ),
              const SizedBox(height: 40),

              // ─── MODO: ANTES DE CREAR ──────────────────────
              if (_codigoGenerado == null) ...[
                // Botón Crear
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _cargando ? null : _crearEspacio,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text(
                      'Crear espacio nuevo',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('o', style: TextStyle(color: onSurface.withAlpha(120))),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _codigoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Código de invitación',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    hintText: 'Ej. AB12CD',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _cargando ? null : _unirse,
                    icon: const Icon(Icons.link_rounded),
                    label: const Text(
                      'Unirme con código',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

              // ─── MODO: DESPUÉS DE CREAR (muestra código) ──
              ] else ...[
                Text(
                  'Comparte este código con tu pareja:',
                  style: TextStyle(fontSize: 14, color: onSurface.withAlpha(160)),
                ),
                const SizedBox(height: 16),
                // Código grande y copiable
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _codigoGenerado!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Código copiado al portapapeles 📋'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                    decoration: BoxDecoration(
                      color: primary.withAlpha(12),
                      border: Border.all(color: primary.withAlpha(80), width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _codigoGenerado!,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: primary,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.copy_rounded, color: primary.withAlpha(160), size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Toca el código para copiarlo',
                  style: TextStyle(fontSize: 12, color: onSurface.withAlpha(100)),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _continuar,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
              ],

              // ─── ERROR ─────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ─── LOADING ───────────────────────────────────
              if (_cargando) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
