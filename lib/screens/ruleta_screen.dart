import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class RuletaScreen extends StatefulWidget {
  const RuletaScreen({super.key});

  @override
  State createState() => _RuletaScreenState();
}
 
class _RuletaScreenState extends State<RuletaScreen> with SingleTickerProviderStateMixin {
  final List<String> _planes = [
    'Salir por una Marquesita o un Frappe',
    'Ir a comer pizza',
    'Hacer la cena en casa',
    'Ir a correr',
    'Ir por sushi',
    'Noche de Películas en Casa',
    'Cocinar cena juntos',
    'Paseo por el Centro',
    'Tarde de videojuegos',
    'Ir por un helado',
    'Salir por un café',
    'Caminata por la playa',
    'Visitar un museo',
    'Picnic en la plancha',
    'Cena en un restaurante diferente',
    'Montar bicicleta',
    'Jugar en el parque',
    'Ir de compras',
    'Ir a una plaza',
    'Ir a un partido de fútbol',
    'Ir a un partido de baloncesto',
    'Ir a caminar',
  ];

  String _planActual = '¿Qué hacemos hoy?';
  bool _estaGirando = false;
  late AnimationController _animacionController;

  @override
  void initState() {
    super.initState();
    _animacionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animacionController.dispose();
    super.dispose();
  }

  void _girarRuleta() {
    if (_estaGirando) return;

    setState(() {
      _estaGirando = true;
    });

    int tiempoDeGiro = 0;
    final random = Random();

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _planActual = _planes[random.nextInt(_planes.length)];
      });

      tiempoDeGiro += 100;

      if (tiempoDeGiro >= 2500) {
        timer.cancel();
        setState(() {
          _estaGirando = false;
        });
        _mostrarGanador(_planActual);
      }
    });
  }

  void _mostrarGanador(String planGanador) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¡El destino ha hablado!', textAlign: TextAlign.center),
        content: Text(
          planGanador,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface,
                foregroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('¡Me encanta!'),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '¿Sin ideas?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Deja que la suerte decida nuestra próxima cita.',
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              AnimatedBuilder(
                animation: _animacionController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _estaGirando ? 1.0 : 1.0 + (_animacionController.value * 0.05),
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).cardColor,
                        border: Border.all(
                          color: _estaGirando ? Theme.of(context).colorScheme.primary : const Color(0xFFEAEDED),
                          width: _estaGirando ? 4 : 8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withAlpha(((_estaGirando ? 0.2 : 0.05) * 255).round()),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            _planActual,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _estaGirando ? 18 : 22,
                              fontWeight: _estaGirando ? FontWeight.normal : FontWeight.bold,
                              color: _estaGirando ? Theme.of(context).colorScheme.onSurface.withAlpha(140) : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 200,
                height: 56,
                child: ElevatedButton(
                  onPressed: _estaGirando ? null : _girarRuleta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: _estaGirando ? 0 : 8,
                  ),
                  child: Text(
                    _estaGirando ? 'GIRANDO...' : 'TIRAR DADOS',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
