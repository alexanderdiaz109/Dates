import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/supabase_config.dart';

class PantallaDetalleRecuerdo extends StatelessWidget {
  final Map<String, dynamic> recuerdo;

  const PantallaDetalleRecuerdo({super.key, required this.recuerdo});

  List<String> _parseImages(String? urlField) {
    if (urlField == null || urlField.isEmpty) return [];
    if (urlField.startsWith('[') && urlField.endsWith(']')) {
      try {
        final List<dynamic> decoded = jsonDecode(urlField);
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return [urlField];
      }
    }
    return [urlField];
  }

  @override
  Widget build(BuildContext context) {
    final imagenes = _parseImages(recuerdo['imagen_url']);

    return Scaffold(
      backgroundColor: Colors.black, // Fondo oscuro para resaltar la foto
      extendBodyBehindAppBar: true, // Que la foto ocupe hasta la barra de arriba
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // La foto ocupa todo el fondo, conectada con el tag Hero
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: imagenes.isEmpty
                ? const SizedBox()
                : PageView.builder(
                    itemCount: imagenes.length,
                    itemBuilder: (context, index) {
                      final imgWidget = CachedNetworkImage(
                        imageUrl: SupabaseConfig.imagenOptimizada(imagenes[index], width: 600, quality: 80),
                        fit: BoxFit.cover,
                      );

                      if (index == 0) {
                        return Hero(
                          tag: 'foto_${recuerdo['id']}',
                          child: imgWidget,
                        );
                      }
                      return imgWidget;
                    },
                  ),
          ),

          // Un degradado más grande para tapar un poco la parte de abajo
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      int estrellas = recuerdo['calificacion'] ?? 5;
                      return Icon(
                        index < estrellas ? Icons.star_rounded : Icons.star_border_rounded,
                        color: const Color(0xFFFFC107),
                        size: 24,
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    recuerdo['titulo'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    recuerdo['comentario'] ?? 'Sin detalles adicionales.',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          
          if (imagenes.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.swipe_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Deslizar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
