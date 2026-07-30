import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class VisorImagenScreen extends StatelessWidget {
  final String urlImagen;
  final String titulo;

  const VisorImagenScreen({super.key, required this.urlImagen, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      extendBodyBehindAppBar: true,
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(
          child: Hero(
            tag: urlImagen,
            child: CachedNetworkImage(imageUrl: urlImagen, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
