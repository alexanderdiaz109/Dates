"""
Convierte Logo.png a una silueta blanca sobre fondo transparente.
Esta version detecta y elimina el fondo negro del logo.
"""
from PIL import Image

# Rutas
entrada = r"assets\Logo.png"
salida = r"android\app\src\main\res\drawable\ic_notificacion.png"

img = Image.open(entrada).convert("RGBA")
resultado = Image.new("RGBA", img.size, (0, 0, 0, 0))

pixels_in = img.load()
pixels_out = resultado.load()

for y in range(img.height):
    for x in range(img.width):
        r, g, b, a = pixels_in[x, y]

        # Detectar fondo negro: pixeles donde RGB son todos muy oscuros
        es_negro = (r < 40 and g < 40 and b < 40)

        if es_negro or a < 20:
            # Fondo negro o transparente -> lo dejamos transparente
            pixels_out[x, y] = (0, 0, 0, 0)
        else:
            # Parte del logo (corazon dorado, etc.) -> lo hacemos blanco
            # Preservamos la opacidad original para bordes suaves
            pixels_out[x, y] = (255, 255, 255, a)

resultado.save(salida, "PNG")
print(f"LISTO! Guardado en: {salida}")
print(f"Tamano: {resultado.size[0]}x{resultado.size[1]}px")
