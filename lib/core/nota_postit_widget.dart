import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'temporada_service.dart';
import 'temporada_theme.dart';

class NotaPostItWidget extends StatefulWidget {
  final String texto;
  final int colorHex;
  final int index;
  final String notaId;
  final String? reaccion;
  final VoidCallback onEliminar;

  const NotaPostItWidget({
    super.key,
    required this.texto,
    required this.colorHex,
    required this.index,
    required this.notaId,
    required this.onEliminar,
    this.reaccion,
  });

  @override
  State<NotaPostItWidget> createState() => _NotaPostItWidgetState();
}

class _NotaPostItWidgetState extends State<NotaPostItWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _reaccionController;
  late Animation<double> _reaccionScale;
  String? _reaccionLocal;

  static const List<String> _emojis = ['❤️', '😂', '😍', '😮', '😢', '🔥'];
  static final _temporadaTheme = TemporadaTheme(TemporadaService.detectar());

  @override
  void initState() {
    super.initState();
    _reaccionLocal = widget.reaccion;
    _reaccionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _reaccionScale = CurvedAnimation(
      parent: _reaccionController,
      curve: Curves.elasticOut,
    );
    if (_reaccionLocal != null && _reaccionLocal!.isNotEmpty) {
      _reaccionController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(NotaPostItWidget old) {
    super.didUpdateWidget(old);
    if (widget.reaccion != old.reaccion) {
      setState(() => _reaccionLocal = widget.reaccion);
      if (widget.reaccion != null && widget.reaccion!.isNotEmpty) {
        _reaccionController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _reaccionController.dispose();
    super.dispose();
  }

  Future<void> _guardarReaccion(String emoji) async {
    HapticFeedback.mediumImpact();
    setState(() => _reaccionLocal = emoji);
    _reaccionController.forward(from: 0);
    await Supabase.instance.client
        .from('notas')
        .update({'reaccion': emoji})
        .eq('id', widget.notaId);
  }

  Future<void> _quitarReaccion() async {
    setState(() => _reaccionLocal = null);
    await Supabase.instance.client
        .from('notas')
        .update({'reaccion': null})
        .eq('id', widget.notaId);
  }

  void _mostrarOpciones() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MenuOpciones(
        emojis: _emojis,
        reaccionActual: _reaccionLocal,
        onReaccionar: (emoji) {
          Navigator.pop(ctx);
          _guardarReaccion(emoji);
        },
        onQuitarReaccion: () {
          Navigator.pop(ctx);
          _quitarReaccion();
        },
        onEliminar: () {
          Navigator.pop(ctx);
          widget.onEliminar();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final random = Random(widget.index);
    final angulo = (random.nextDouble() * 0.12) - 0.06;
    final tieneReaccion = _reaccionLocal != null && _reaccionLocal!.isNotEmpty;

    return Transform.rotate(
      angle: angulo,
      child: GestureDetector(
        onLongPress: _mostrarOpciones,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // ── PAPEL ─────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              padding: EdgeInsets.fromLTRB(
                  16, 24, 16, tieneReaccion ? 32 : 16),
              decoration: BoxDecoration(
                color: Color(widget.colorHex),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(widget.colorHex).withAlpha(120),
                    blurRadius: 6,
                    offset: const Offset(3, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(4, 6),
                  ),
                ],
              ),
              child: Text(
                widget.texto,
                style: GoogleFonts.kalam(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2C3E50),
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // ── WASHI TAPE (color de temporada) ──────────────────
            Positioned(
              top: 0,
              child: Transform.rotate(
                angle: (random.nextDouble() * 0.08) - 0.04,
                child: Container(
                  width: 42,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _temporadaTheme.washiTapeColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── DETALLE DECORATIVO (esquina superior derecha) ─────
            if (_temporadaTheme.postItPainter(Colors.black38) != null)
              Positioned(
                top: 8,
                right: 8,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CustomPaint(
                    painter: _temporadaTheme.postItPainter(Colors.black26),
                  ),
                ),
              ),

            // ── REACCIÓN ──────────────────────────────────
            if (tieneReaccion)
              Positioned(
                bottom: 4,
                right: 8,
                child: ScaleTransition(
                  scale: _reaccionScale,
                  child: GestureDetector(
                    onTap: _mostrarOpciones,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(200),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _reaccionLocal!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── MENÚ DE OPCIONES ──────────────────────────────────────────────
class _MenuOpciones extends StatelessWidget {
  final List<String> emojis;
  final String? reaccionActual;
  final void Function(String) onReaccionar;
  final VoidCallback onQuitarReaccion;
  final VoidCallback onEliminar;

  const _MenuOpciones({
    required this.emojis,
    required this.reaccionActual,
    required this.onReaccionar,
    required this.onQuitarReaccion,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Emojis de reacción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((emoji) {
              final esActual = reaccionActual == emoji;
              return GestureDetector(
                onTap: () => onReaccionar(emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: esActual
                        ? Theme.of(context).colorScheme.primary.withAlpha(30)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: esActual
                        ? Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withAlpha(80),
                            width: 2,
                          )
                        : null,
                  ),
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: esActual ? 28 : 24,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          Divider(color: Theme.of(context).dividerColor.withAlpha(60)),
          const SizedBox(height: 8),

          // Quitar reacción (solo si hay una)
          if (reaccionActual != null && reaccionActual!.isNotEmpty)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                  size: 20,
                ),
              ),
              title: Text(
                'Quitar reacción',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onTap: onQuitarReaccion,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),

          // Eliminar nota
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 20),
            ),
            title: const Text(
              'Eliminar nota',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
            onTap: onEliminar,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ],
      ),
    );
  }
}
