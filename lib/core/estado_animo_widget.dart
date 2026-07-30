import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class EstadoAnimoWidget extends StatelessWidget {
  const EstadoAnimoWidget({super.key});

  static const List<Map<String, String>> _estados = [
    // Amor & Pareja
    {'emoji': '😍', 'texto': 'Enamorad@'},
    {'emoji': '🥰', 'texto': 'Feliz contigo'},
    {'emoji': '😔', 'texto': 'Extrañándote'},
    {'emoji': '🤗', 'texto': 'Abrazable'},
    {'emoji': '💋', 'texto': 'Mimos@'},
    {'emoji': '🥺', 'texto': 'Necesito cariño'},
    {'emoji': '💍', 'texto': 'Pensando en futuro'},
    
    // Positivos / Felices
    {'emoji': '😊', 'texto': 'Bien'},
    {'emoji': '🤩', 'texto': 'Emocionad@'},
    {'emoji': '😎', 'texto': 'Relajad@'},
    {'emoji': '🥳', 'texto': 'De fiesta'},
    {'emoji': '😇', 'texto': 'Sintiéndome un ángel'},
    {'emoji': '🤭', 'texto': 'Travies@'},
    {'emoji': '😜', 'texto': 'Juguetón/a'},
    {'emoji': '✨', 'texto': 'Vibrando alto'},
    {'emoji': '😌', 'texto': 'Tranquil@'},
    
    // Energía & Productividad
    {'emoji': '💪', 'texto': 'Con energía'},
    {'emoji': '🏃', 'texto': 'Haciendo ejercicio'},
    {'emoji': '🤓', 'texto': 'Productiv@'},
    {'emoji': '😤', 'texto': 'Ocupad@'},
    {'emoji': '🧠', 'texto': 'Pensando mucho'},
    {'emoji': '💼', 'texto': 'Trabajando duro'},
    {'emoji': '📚', 'texto': 'Estudiando'},
    
    // Comida & Bebida
    {'emoji': '😋', 'texto': 'Con hambre'},
    {'emoji': '🤤', 'texto': 'Antojad@'},
    {'emoji': '🍔', 'texto': 'Modo gordo/a'},
    {'emoji': '🍕', 'texto': 'Quiero pizza'},
    {'emoji': '☕', 'texto': 'Necesito café'},
    {'emoji': '🍷', 'texto': 'Quiero vinito'},
    {'emoji': '🍻', 'texto': 'Sed de la mala'},
    
    // Cansancio & Salud
    {'emoji': '😴', 'texto': 'Con sueño'},
    {'emoji': '🥱', 'texto': 'Cansad@'},
    {'emoji': '🛌', 'texto': 'No me quiero parar'},
    {'emoji': '🌙', 'texto': 'Con insomnio'},
    {'emoji': '🤒', 'texto': 'Malito/a'},
    {'emoji': '🤧', 'texto': 'Resfriad@'},
    {'emoji': '🤕', 'texto': 'Me duele algo'},
    {'emoji': '😵', 'texto': 'Maread@'},
    
    // Negativos / Estresados
    {'emoji': '😢', 'texto': 'Triste'},
    {'emoji': '😭', 'texto': 'Sensible'},
    {'emoji': '😡', 'texto': 'Enojad@'},
    {'emoji': '🤬', 'texto': 'Harto/a'},
    {'emoji': '😅', 'texto': 'Estresad@'},
    {'emoji': '🫠', 'texto': 'Derritiéndome'},
    {'emoji': '🙃', 'texto': 'Valiendo queso'},
    {'emoji': '🤯', 'texto': 'Me explota la cabeza'},
    {'emoji': '🥶', 'texto': 'Con mucho frío'},
    {'emoji': '🥵', 'texto': 'Con mucho calor'},
    {'emoji': '🙄', 'texto': 'Fastidiad@'},
    
    // Otros / Random
    {'emoji': '🤔', 'texto': 'Pensativ@'},
    {'emoji': '🎮', 'texto': 'Jugando'},
    {'emoji': '🎧', 'texto': 'Escuchando música'},
    {'emoji': '🎬', 'texto': 'Viendo películas'},
    {'emoji': '📺', 'texto': 'Viendo series'},
    {'emoji': '🛍️', 'texto': 'Quiero comprar'},
    {'emoji': '🚗', 'texto': 'Manejando'},
    {'emoji': '✈️', 'texto': 'Viajando'},
    {'emoji': '🛀', 'texto': 'En la ducha/baño'},
    {'emoji': '💩', 'texto': 'En el baño'},
  ];

  bool _estaVigente(String? fechaStr) {
    if (fechaStr == null) return false;
    final fecha = DateTime.tryParse(fechaStr);
    if (fecha == null) return false;
    return DateTime.now().difference(fecha).inHours < 24;
  }

  String _tiempoTranscurrido(String? fechaStr) {
    if (fechaStr == null) return '';
    final fecha = DateTime.tryParse(fechaStr);
    if (fecha == null) return '';
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return '';
  }

  void _mostrarOpciones(BuildContext context, bool esMio,
      Map<String, dynamic> datosUsuario) {
    if (!esMio) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BottomSheetEstado(
        estados: _estados,
        estadoActual: datosUsuario['estado_emoji'] as String? ?? '',
        onSeleccionar: (emoji, texto) async {
          Navigator.pop(ctx);
          HapticFeedback.mediumImpact();
          await SupabaseConfig.guardarEstado(emoji, texto);
        },
        onLimpiar: () async {
          Navigator.pop(ctx);
          await SupabaseConfig.guardarEstado('', '');
        },
        onCambiarFoto: () async {
          Navigator.pop(ctx);
          await _subirFotoEstado(context);
        },
      ),
    );
  }

  Future<void> _subirFotoEstado(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return;

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last;
      final nombre = 'estado_$userId.$ext';

      await Supabase.instance.client.storage
          .from('estados')
          .uploadBinary(nombre, bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: 'image/$ext',
              ));

      final url = Supabase.instance.client.storage
          .from('estados')
          .getPublicUrl(nombre);

      await Supabase.instance.client
          .from('usuarios')
          .update({'foto_estado_url': url})
          .eq('id', userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto actualizada '),
            backgroundColor: Color(0xFFFF6A88),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('usuarios')
          .stream(primaryKey: ['id'])
          .eq('pareja_id', SupabaseConfig.parejaId ?? ''),
      builder: (context, snap) {
        final usuarios = snap.data ?? [];
        final miId = SupabaseConfig.currentUserId;

        final yo = usuarios.firstWhere(
          (u) => u['id'] == miId,
          orElse: () => {},
        );
        final pareja = usuarios.firstWhere(
          (u) => u['id'] != miId,
          orElse: () => {},
        );

        final yoVigente = _estaVigente(yo['estado_actualizado_en']);
        final parejaVigente = _estaVigente(pareja['estado_actualizado_en']);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                '¿Cómo estamos hoy?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _mostrarOpciones(context, true, yo),
                    child: _StoryCard(
                      emoji: yoVigente ? (yo['estado_emoji'] ?? '') : '',
                      texto: yoVigente ? (yo['estado_texto'] ?? '') : '',
                      nombre: 'Yo',
                      fotoUrl: yo['foto_estado_url'] as String?,
                      tiempo: yoVigente
                          ? _tiempoTranscurrido(yo['estado_actualizado_en'])
                          : '',
                      esMio: true,
                      tieneEstado: yoVigente &&
                          (yo['estado_emoji'] ?? '').isNotEmpty,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StoryCard(
                    emoji: parejaVigente
                        ? (pareja['estado_emoji'] ?? '')
                        : '',
                    texto: parejaVigente
                        ? (pareja['estado_texto'] ?? '')
                        : '',
                    nombre: pareja['nombre'] as String? ?? 'Mi pareja',
                    fotoUrl: pareja['foto_estado_url'] as String?,
                    tiempo: parejaVigente
                        ? _tiempoTranscurrido(
                            pareja['estado_actualizado_en'])
                        : '',
                    esMio: false,
                    tieneEstado: parejaVigente &&
                        (pareja['estado_emoji'] ?? '').isNotEmpty,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── STORY CARD ────────────────────────────────────────────────────
class _StoryCard extends StatelessWidget {
  final String emoji;
  final String texto;
  final String nombre;
  final String? fotoUrl;
  final String tiempo;
  final bool esMio;
  final bool tieneEstado;

  static const _rosa = Color(0xFFFF6A88);
  static const _azul = Color(0xFF7B9EFF);

  const _StoryCard({
    required this.emoji,
    required this.texto,
    required this.nombre,
    required this.fotoUrl,
    required this.tiempo,
    required this.esMio,
    required this.tieneEstado,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = esMio ? _rosa : _azul;
    final hasPhoto = fotoUrl != null && fotoUrl!.isNotEmpty;

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: tieneEstado
                ? borderColor
                : esMio
                    ? borderColor.withAlpha(80)
                    : borderColor.withAlpha(40),
            width: tieneEstado ? 2.5 : (esMio ? 1.5 : 1),
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Fondo ───────────────────────────
              if (hasPhoto)
                Image.network(
                  SupabaseConfig.imagenOptimizada(fotoUrl, width: 400, quality: 75),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _FondoDefault(
                    esMio: esMio,
                    borderColor: borderColor,
                  ),
                )
              else
                _FondoDefault(
                  esMio: esMio,
                  borderColor: borderColor,
                ),

              // ── Overlay oscuro abajo ─────────────
              if (hasPhoto || tieneEstado)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withAlpha(180),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Emoji grande (centro) ────────────
              if (tieneEstado)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withAlpha(50),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (!hasPhoto)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: borderColor.withAlpha(25),
                        ),
                        child: Center(
                          child: Text(
                            esMio ? '✎' : '💫',
                            style: TextStyle(
                              fontSize: esMio ? 20 : 24,
                              color: esMio ? borderColor : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        esMio ? 'Toca para\nagregar' : 'Sin estado aún',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: borderColor.withAlpha(160),
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Botón editar (solo mío) ──────────
              if (esMio)
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(220),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: borderColor,
                    ),
                  ),
                ),

              // ── Info inferior ────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tieneEstado)
                        Text(
                          texto,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            nombre,
                            style: TextStyle(
                              fontSize: 10,
                              color: tieneEstado || hasPhoto
                                  ? Colors.white.withAlpha(180)
                                  : borderColor.withAlpha(150),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                              shadows: tieneEstado || hasPhoto ? const [
                                Shadow(color: Colors.black38, blurRadius: 4),
                              ] : null,
                            ),
                          ),
                          if (tiempo.isNotEmpty)
                            Text(
                              tiempo,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black38, blurRadius: 4),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
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

// ── FONDO DEFAULT ─────────────────────────────────────────────────
class _FondoDefault extends StatelessWidget {
  final bool esMio;
  final Color borderColor;

  const _FondoDefault({required this.esMio, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: esMio
              ? [
                  const Color(0xFFFFD6E0),
                  const Color(0xFFFF8FAB),
                ]
              : [
                  const Color(0xFFE8EDFF),
                  const Color(0xFFB8C8FF),
                ],
        ),
      ),
    );
  }
}

// ── BOTTOM SHEET ──────────────────────────────────────────────────
class _BottomSheetEstado extends StatefulWidget {
  final List<Map<String, String>> estados;
  final String estadoActual;
  final void Function(String emoji, String texto) onSeleccionar;
  final VoidCallback onLimpiar;
  final VoidCallback onCambiarFoto;

  const _BottomSheetEstado({
    required this.estados,
    required this.estadoActual,
    required this.onSeleccionar,
    required this.onLimpiar,
    required this.onCambiarFoto,
  });

  @override
  State<_BottomSheetEstado> createState() => _BottomSheetEstadoState();
}

class _BottomSheetEstadoState extends State<_BottomSheetEstado> {
  String? _preview;
  String? _textoPreview;

  static const _rosa = Color(0xFFFF6A88);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Preview
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(
                  parent: anim, curve: Curves.elasticOut),
              child: child,
            ),
            child: _preview != null
                ? Column(
                    key: ValueKey(_preview),
                    children: [
                      Text(_preview!,
                          style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 6),
                      Text(
                        _textoPreview ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('hint'),
                    children: [
                      Text(
                        '¿Cómo estás hoy?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tu pareja lo verá en el inicio',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(120),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 20),

          // Botón cambiar foto
          GestureDetector(
            onTap: widget.onCambiarFoto,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _rosa.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _rosa.withAlpha(60), width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded,
                      size: 16, color: _rosa),
                  const SizedBox(width: 8),
                  Text(
                    'Cambiar foto de fondo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _rosa,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Grid de estados
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: widget.estados.map((e) {
                  final seleccionado = _preview == e['emoji'];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _preview = e['emoji'];
                        _textoPreview = e['texto'];
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: seleccionado
                            ? _rosa.withAlpha(25)
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: seleccionado
                              ? _rosa.withAlpha(100)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e['emoji']!,
                              style: TextStyle(
                                  fontSize: seleccionado ? 22 : 20)),
                          const SizedBox(width: 6),
                          Text(
                            e['texto']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: seleccionado
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: seleccionado
                                  ? _rosa
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Botón confirmar
          AnimatedOpacity(
            opacity: _preview != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _preview != null
                    ? () => widget.onSeleccionar(
                        _preview!, _textoPreview!)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _rosa,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Compartir estado',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          TextButton(
            onPressed: widget.onLimpiar,
            child: Text(
              'Sin estado por hoy',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(120),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
