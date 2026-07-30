import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../core/pin_hash.dart';
import '../core/supabase_config.dart';
import '../main_navigation.dart';

class LoginPinScreen extends StatefulWidget {
  const LoginPinScreen({super.key});

  @override
  State<LoginPinScreen> createState() => _LoginPinScreenState();
}

class _LoginPinScreenState extends State<LoginPinScreen>
    with SingleTickerProviderStateMixin {
  String _pinIngresado = '';
  final int _longitudPin = 8;
  bool _pinIncorrecto = false;
  String? _pinReal;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Animación de shake cuando el PIN es incorrecto
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _cargarPinReal();
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
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _presionarTecla(String numero) {
    if (_pinIngresado.length >= _longitudPin) return;
    HapticFeedback.lightImpact(); // Vibración táctil al presionar
    setState(() {
      _pinIngresado += numero;
      _pinIncorrecto = false;
    });
    if (_pinIngresado.length == _longitudPin) {
      _validarPin();
    }
  }

  void _borrarTecla() {
    if (_pinIngresado.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pinIngresado = _pinIngresado.substring(0, _pinIngresado.length - 1);
      _pinIncorrecto = false;
    });
  }

  Future<void> _cargarPinReal() async {
    final pin = await SupabaseConfig.obtenerPinLocal();
    if (mounted) setState(() => _pinReal = pin);
  }

  Future<void> _validarPin() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (_pinReal != null && PinHash.verificar(_pinIngresado, _pinReal!)) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainNavigation(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      setState(() {
        _pinIncorrecto = true;
        _pinIngresado = '';
      });
    }
  }

  Future<void> _usarBiometria() async {
    try {
      // Verificar si el dispositivo soporta biometría
      final disponible = await _localAuth.canCheckBiometrics;
      final soportado = await _localAuth.isDeviceSupported();

      if (!disponible || !soportado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este dispositivo no tiene biometría configurada 🔒'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Intentar autenticar con huella/face
      final autenticado = await _localAuth.authenticate(
        localizedReason: 'Usa tu huella para entrar a Nuestro Espacio',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (autenticado && mounted) {
        // Éxito — navegamos igual que con el PIN correcto
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainNavigation(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al usar biometría: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 56),

            // ─── CABECERA ───────────────────────────────────────
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
              'Nuestro Espacio',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingresa tu PIN ',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withAlpha(140)),
            ),

            const SizedBox(height: 48),

            // ─── PUNTITOS DEL PIN con animación shake ──────────
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_longitudPin, (i) {
                  final lleno = i < _pinIngresado.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    height: lleno ? 18 : 16,
                    width: lleno ? 18 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _pinIncorrecto
                          ? Colors.redAccent
                          : lleno
                              ? primary
                              : Colors.transparent,
                      border: Border.all(
                        color: _pinIncorrecto
                            ? Colors.redAccent
                            : lleno
                                ? primary
                                : const Color(0xFFBDC3C7),
                        width: 2,
                      ),
                      boxShadow: lleno && !_pinIncorrecto
                          ? [
                              BoxShadow(
                                  color: primary.withAlpha(80),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ]
                          : [],
                    ),
                  );
                }),
              ),
            ),

            // Mensaje de error animado
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _pinIncorrecto
                  ? const Padding(
                      key: ValueKey('error'),
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'PIN incorrecto, intenta de nuevo',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : const SizedBox(key: ValueKey('empty'), height: 36),
            ),

            const Spacer(),

            // ─── TECLADO NUMÉRICO ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
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
                      _buildBotonAccion(
                          Icons.fingerprint_rounded, _usarBiometria,
                          color: primary),
                      _buildTecla('0'),
                      _buildBotonAccion(
                          Icons.backspace_outlined, _borrarTecla),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ─── BOTÓN SECUNDARIO ───────────────────────────────
            TextButton(
              onPressed: () {},
              child: const Text(
                'Olvidé mi PIN',
                style: TextStyle(
                  color: Color(0xFFBDC3C7),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────

  Row _filaNumeros(List<String> nums) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: nums.map((n) => _buildTecla(n)).toList(),
    );
  }

  Widget _buildTecla(String numero) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _presionarTecla(numero),
        borderRadius: BorderRadius.circular(40),
        splashColor:
            Theme.of(context).colorScheme.primary.withAlpha(25),
        highlightColor: Colors.transparent,
        child: Container(
          height: 75,
          width: 75,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Sutil fondo para dar profundidad
            color: Theme.of(context).colorScheme.onSurface.withAlpha(60),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Text(
            numero,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotonAccion(IconData icono, VoidCallback accion,
      {Color? color}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: accion,
        borderRadius: BorderRadius.circular(40),
        splashColor: const Color(0x0A000000),
        highlightColor: Colors.transparent,
        child: Container(
          height: 75,
          width: 75,
          alignment: Alignment.center,
          child: Icon(
            icono,
            size: 28,
            color: color ?? const Color(0xFFBDC3C7),
          ),
        ),
      ),
    );
  }
}
