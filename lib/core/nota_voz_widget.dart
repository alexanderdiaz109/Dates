import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'temporada_service.dart';
import 'temporada_theme.dart';

class NotaVozWidget extends StatefulWidget {
  final String notaId;
  final String audioUrl;
  final int duracionSegundos;
  final int index;
  final String? reaccion;
  final VoidCallback onEliminar;

  const NotaVozWidget({
    super.key,
    required this.notaId,
    required this.audioUrl,
    required this.duracionSegundos,
    required this.index,
    required this.onEliminar,
    this.reaccion,
  });

  @override
  State<NotaVozWidget> createState() => _NotaVozWidgetState();
}

class _NotaVozWidgetState extends State<NotaVozWidget>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  late AnimationController _reaccionController;
  late Animation<double> _reaccionScale;
  String? _reaccionLocal;
  bool _reproduciendo = false;
  Duration _posicion = Duration.zero;
  Duration _duracion = Duration.zero;

  static const List<String> _emojis = ['❤️', '😂', '😍', '😮', '😢', '🔥'];
  static final _temporadaTheme = TemporadaTheme(TemporadaService.detectar());

  // Barras de onda generadas de forma determinista según el id de la nota
  late final List<double> _barras;

  @override
  void initState() {
    super.initState();
    _reaccionLocal = widget.reaccion;
    _duracion = Duration(seconds: widget.duracionSegundos);

    // Generar onda pseudoaleatoria consistente
    final seed = widget.notaId.codeUnits.fold(0, (a, b) => a + b);
    final rand = Random(seed);
    _barras = List.generate(22, (_) => 0.2 + rand.nextDouble() * 0.8);

    _player = AudioPlayer();
    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _posicion = pos);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _reproduciendo =
            state.playing &&
            state.processingState != ProcessingState.completed);
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          setState(() => _posicion = Duration.zero);
        }
      }
    });

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
  void didUpdateWidget(NotaVozWidget old) {
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
    _player.dispose();
    _reaccionController.dispose();
    super.dispose();
  }

  Future<void> _toggleReproduccion() async {
    HapticFeedback.lightImpact();
    if (_reproduciendo) {
      await _player.pause();
    } else {
      if (_player.audioSource == null) {
        await _player.setUrl(widget.audioUrl);
        final dur = _player.duration;
        if (dur != null && mounted) setState(() => _duracion = dur);
      }
      await _player.play();
    }
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
      builder: (ctx) => _MenuOpcionesVoz(
        emojis: _emojis,
        reaccionActual: _reaccionLocal,
        onReaccionar: (e) { Navigator.pop(ctx); _guardarReaccion(e); },
        onQuitarReaccion: () { Navigator.pop(ctx); _quitarReaccion(); },
        onEliminar: () { Navigator.pop(ctx); widget.onEliminar(); },
      ),
    );
  }

  String _formatearTiempo(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final rand = Random(widget.index);
    final angulo = (rand.nextDouble() * 0.10) - 0.05;
    final tieneReaccion = _reaccionLocal != null && _reaccionLocal!.isNotEmpty;
    final progreso = _duracion.inMilliseconds > 0
        ? (_posicion.inMilliseconds / _duracion.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Transform.rotate(
      angle: angulo,
      child: GestureDetector(
        onLongPress: _mostrarOpciones,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // ── TARJETA ──────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1E2E), Color(0xFF2D1F3D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(14),
                ),
                border: Border(
                  top: BorderSide(
                    color: _temporadaTheme.accentColor.withAlpha(120),
                    width: 2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D1F3D).withAlpha(100),
                    blurRadius: 10,
                    offset: const Offset(3, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 16,
                    offset: const Offset(4, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── ONDA DE AUDIO ─────────────────────
                  SizedBox(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(_barras.length, (i) {
                        final fraccion = i / _barras.length;
                        final activa = fraccion <= progreso;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: 3,
                            height: _barras[i] * 30,
                            decoration: BoxDecoration(
                              color: activa
                                  ? const Color(0xFFFF6A88)
                                  : Colors.white.withAlpha(60),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── CONTROLES ────────────────────────
                  Row(
                    children: [
                      // Botón play/pause
                      GestureDetector(
                        onTap: _toggleReproduccion,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _reproduciendo
                                ? const Color(0xFFFF6A88)
                                : Colors.white.withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF6A88).withAlpha(150),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _reproduciendo
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: _reproduciendo
                                ? Colors.white
                                : const Color(0xFFFF6A88),
                            size: 22,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Barra de progreso + tiempo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Barra
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progreso,
                                backgroundColor: Colors.white.withAlpha(30),
                                valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFFFF6A88)),
                                minHeight: 3,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Tiempo
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatearTiempo(_posicion),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withAlpha(150),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatearTiempo(_duracion),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withAlpha(80),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── REACCIÓN ─────────────────────────
                  if (tieneReaccion)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ScaleTransition(
                          scale: _reaccionScale,
                          child: GestureDetector(
                            onTap: _mostrarOpciones,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_reaccionLocal!,
                                  style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── WASHI TAPE ────────────────────────────
            Positioned(
              top: 0,
              child: Transform.rotate(
                angle: (rand.nextDouble() * 0.08) - 0.04,
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
          ],
        ),
      ),
    );
  }
}

// ── MENÚ DE OPCIONES PARA NOTA DE VOZ ────────────────────────────
class _MenuOpcionesVoz extends StatelessWidget {
  final List<String> emojis;
  final String? reaccionActual;
  final void Function(String) onReaccionar;
  final VoidCallback onQuitarReaccion;
  final VoidCallback onEliminar;

  const _MenuOpcionesVoz({
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
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
                            color: Theme.of(context).colorScheme.primary.withAlpha(80),
                            width: 2)
                        : null,
                  ),
                  child: Text(emoji,
                      style: TextStyle(fontSize: esActual ? 28 : 24)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Divider(color: Theme.of(context).dividerColor.withAlpha(60)),
          if (reaccionActual != null && reaccionActual!.isNotEmpty)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.remove_circle_outline_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                    size: 20),
              ),
              title: Text('Quitar reacción',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
              onTap: onQuitarReaccion,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
            title: const Text('Eliminar nota de voz',
                style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
            onTap: onEliminar,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ],
      ),
    );
  }
}
