import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/supabase_config.dart';
import 'login_pin_screen.dart';

class CrearPinScreen extends StatefulWidget {
  const CrearPinScreen({super.key});

  @override
  State<CrearPinScreen> createState() => _CrearPinScreenState();
}

class _CrearPinScreenState extends State<CrearPinScreen>
    with SingleTickerProviderStateMixin {
  final int _longitudPin = 8;
  String _primerPin = '';
  String _pinActual = '';
  bool _confirmando = false;
  bool _error = false;
  bool _guardando = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _presionarTecla(String numero) {
    if (_pinActual.length >= _longitudPin) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pinActual += numero;
      _error = false;
    });
    if (_pinActual.length == _longitudPin) _procesarPin();
  }

  void _borrarTecla() {
    if (_pinActual.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pinActual = _pinActual.substring(0, _pinActual.length - 1));
  }

  Future<void> _procesarPin() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    if (!_confirmando) {
      // Primera pasada: guardar y pedir confirmación
      setState(() {
        _primerPin = _pinActual;
        _pinActual = '';
        _confirmando = true;
      });
      return;
    }

    // Segunda pasada: verificar que coincidan
    if (_pinActual == _primerPin) {
      setState(() => _guardando = true);
      await SupabaseConfig.guardarPinLocal(_pinActual);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (ctx, anim, sec) => const LoginPinScreen(),
          transitionsBuilder: (ctx, anim, sec, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      setState(() {
        _error = true;
        _pinActual = '';
        _confirmando = false;
        _primerPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 56),

            // ─── ÍCONO ─────────────────────────────────────
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withAlpha(20),
                border: Border.all(color: primary.withAlpha(60), width: 2),
              ),
              child: Icon(Icons.lock_outline_rounded, size: 38, color: primary),
            ),
            const SizedBox(height: 20),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _confirmando ? 'Confirma tu PIN' : 'Crea un PIN de 8 dígitos',
                key: ValueKey(_confirmando),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lo usarás para desbloquear la app cada vez',
              style: TextStyle(fontSize: 13, color: onSurface.withAlpha(140)),
            ),

            const SizedBox(height: 40),

            // ─── PUNTITOS CON SHAKE ────────────────────────
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_longitudPin, (i) {
                  final lleno = i < _pinActual.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: lleno ? 18 : 16,
                    width: lleno ? 18 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _error
                          ? Colors.redAccent
                          : (lleno ? primary : Colors.transparent),
                      border: Border.all(
                        color: _error
                            ? Colors.redAccent
                            : (lleno ? primary : const Color(0xFFBDC3C7)),
                        width: 2,
                      ),
                      boxShadow: lleno && !_error
                          ? [BoxShadow(color: primary.withAlpha(80), blurRadius: 8, offset: const Offset(0, 2))]
                          : [],
                    ),
                  );
                }),
              ),
            ),

            // ─── MENSAJE DE ERROR ──────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _error
                  ? const Padding(
                      key: ValueKey('error'),
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Los PIN no coinciden, intenta de nuevo',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    )
                  : const SizedBox(key: ValueKey('empty'), height: 36),
            ),

            const Spacer(),

            // ─── TECLADO ───────────────────────────────────
            if (_guardando)
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: primary),
                    const SizedBox(height: 16),
                    Text('Guardando PIN...', style: TextStyle(color: onSurface.withAlpha(160), fontSize: 14)),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _filaNumeros(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _filaNumeros(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _filaNumeros(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 75),
                        _buildTecla('0'),
                        _buildBotonAccion(Icons.backspace_outlined, _borrarTecla),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────
  Row _filaNumeros(List<String> nums) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: nums.map(_buildTecla).toList(),
      );

  Widget _buildTecla(String numero) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _presionarTecla(numero),
        borderRadius: BorderRadius.circular(40),
        splashColor: primary.withAlpha(25),
        highlightColor: Colors.transparent,
        child: Container(
          height: 75,
          width: 75,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onSurface.withAlpha(60),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Text(
            numero,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: onSurface),
          ),
        ),
      ),
    );
  }

  Widget _buildBotonAccion(IconData icono, VoidCallback accion, {Color? color}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: accion,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          height: 75,
          width: 75,
          child: Icon(icono, size: 28, color: color ?? const Color(0xFFBDC3C7)),
        ),
      ),
    );
  }
}
