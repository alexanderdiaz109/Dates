import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'supabase_config.dart';

class PasaporteCardWidget extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final bool conquistado;
  final String? imagenUrl;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const PasaporteCardWidget({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.conquistado,
    this.imagenUrl,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Generar un color pastel aleatorio para las tarjetas sin foto
    final int hash = titulo.hashCode;
    final double hue = (hash % 360).toDouble();
    final colorFondo = HSLColor.fromAHSL(1.0, hue, 0.4, 0.9).toColor();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 180,
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Si hay imagen, la ponemos de fondo con un overlay oscuro
              if (imagenUrl != null && imagenUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: SupabaseConfig.imagenOptimizada(imagenUrl!, width: 200, quality: 70),
                  fit: BoxFit.cover,
                ),
              if (imagenUrl != null && imagenUrl!.isNotEmpty)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),

              // Contenido de la tarjeta (Texto)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: (imagenUrl != null && imagenUrl!.isNotEmpty)
                            ? Colors.white
                            : const Color(0xFF2C3E50),
                        shadows: (imagenUrl != null && imagenUrl!.isNotEmpty)
                            ? const [
                                Shadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(1, 1))
                              ]
                            : [],
                      ),
                    ),
                    if (descripcion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: (imagenUrl != null && imagenUrl!.isNotEmpty)
                              ? Colors.white.withValues(alpha: 0.9)
                              : const Color(0xFF7F8C8D),
                          shadows: (imagenUrl != null && imagenUrl!.isNotEmpty)
                              ? const [
                                  Shadow(
                                      color: Colors.black45,
                                      blurRadius: 2,
                                      offset: Offset(1, 1))
                                ]
                              : [],
                        ),
                      ),
                    ]
                  ],
                ),
              ),

              // El sello de "CONQUISTADO" si ya lo cumplieron
              if (conquistado)
                Positioned(
                  top: 20,
                  right: 20,
                  child: Transform.rotate(
                    angle: -0.2, // Ligera rotación para que parezca un sello real
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE74C3C), width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'CONQUISTADO',
                        style: TextStyle(
                          color: Color(0xFFE74C3C),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
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
