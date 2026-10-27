#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera el arte del matraz de ManaBreath.

Sin dependencias: escribe los TGA que carga WoW y un PNG de vista previa
usando solo la biblioteca estandar.

    python tools/make_art.py

Salida en Art/:
    FlaskGlass.tga    cristal, contorno y brillos; el interior va transparente
    FlaskMask.tga     silueta del interior, recorta el liquido y las burbujas
    FlaskLiquid.tga   degradado blanco que se tine desde Lua
    FlaskWave.tga     banda de ola, repetible en horizontal
    FlaskBubble.tga   burbuja
    FlaskGlow.tga     halo del brillo de regeneracion
    Icon.tga          icono para la lista de addons

Y tools/preview.png, que no se empaqueta.

La geometria de abajo es la que Display.lua da por supuesta: si se mueve algo
aqui, hay que mover tambien las constantes FILL_* y GLOW_SCALE de alla.
"""

import math
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ART = os.path.join(REPO, "Art")

SS = 3  # supermuestreo por eje antes de reducir

# --- geometria, en fracciones del lienzo, con y creciendo hacia abajo -------
BULB_CX, BULB_CY, BULB_R = 0.500, 0.655, 0.335
NECK_CX, NECK_CY = 0.500, 0.305
NECK_HW, NECK_HH = 0.1075, 0.215
LIP_CX, LIP_CY = 0.500, 0.085
LIP_HW, LIP_HH = 0.1425, 0.040
LIP_BOTTOM = 0.118
GLASS = 0.030   # grosor de la pared
BLEND = 0.090   # radio de la union suave entre cuello y bulbo

# Las dos constantes que Display.lua repite, medidas desde ABAJO del marco.
FILL_BOTTOM = 0.040
FILL_TOP = 0.660

GLOW_SCALE = 0.74  # cuanto se encoge la silueta dentro del lienzo del halo

C_GLASS = (0.80, 0.87, 0.94)
C_EDGE = (0.09, 0.11, 0.16)
C_WHITE = (1.0, 1.0, 1.0)


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def smoothstep(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def smin(a, b, k):
    h = clamp(0.5 + 0.5 * (b - a) / k)
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


def sd_circle(x, y, cx, cy, r):
    return math.hypot(x - cx, y - cy) - r


def sd_round_box(x, y, cx, cy, hw, hh, r):
    dx = abs(x - cx) - (hw - r)
    dy = abs(y - cy) - (hh - r)
    return math.hypot(max(dx, 0.0), max(dy, 0.0)) + min(max(dx, dy), 0.0) - r


def flask_sdf(x, y):
    """(exterior, interior) del matraz, en coordenadas normalizadas."""
    bulb = sd_circle(x, y, BULB_CX, BULB_CY, BULB_R)
    neck = sd_round_box(x, y, NECK_CX, NECK_CY, NECK_HW, NECK_HH, 0.020)
    body = smin(bulb, neck, BLEND)
    lip = sd_round_box(x, y, LIP_CX, LIP_CY, LIP_HW, LIP_HH, 0.022)
    outer = min(body, lip)
    # El interior se corta justo por debajo del labio: si no, el cuello
    # quedaria abierto por arriba y el liquido podria salirse por ahi.
    inner = max(body + GLASS, LIP_BOTTOM - y)
    return outer, inner


# --- lienzo ----------------------------------------------------------------

class Canvas(object):
    """RGBA en coma flotante, con alfa recto. En los pixeles transparentes se
    deja el color de fondo de la pieza para que el filtrado bilineal de WoW no
    dibuje un halo oscuro alrededor de los bordes."""

    def __init__(self, w, h, bg=(0.0, 0.0, 0.0)):
        self.w, self.h = w, h
        self.px = [[bg[0], bg[1], bg[2], 0.0] for _ in range(w * h)]

    def add(self, i, color, alpha):
        """Mezcla aditiva, como el SetBlendMode("ADD") del juego."""
        p = self.px[i]
        for c in range(3):
            p[c] = clamp(p[c] + color[c] * alpha)

    def over(self, i, color, alpha):
        if alpha <= 0.0:
            return
        if alpha > 1.0:
            alpha = 1.0
        p = self.px[i]
        na = alpha + p[3] * (1.0 - alpha)
        if na <= 0.0:
            return
        for c in range(3):
            p[c] = (color[c] * alpha + p[c] * p[3] * (1.0 - alpha)) / na
        p[3] = na

    def downsample(self, factor):
        w, h = self.w // factor, self.h // factor
        out = Canvas(w, h)
        n = float(factor * factor)
        for y in range(h):
            for x in range(w):
                r = g = b = a = 0.0
                for sy in range(factor):
                    for sx in range(factor):
                        p = self.px[(y * factor + sy) * self.w + x * factor + sx]
                        # Premultiplicado para promediar sin ensuciar el color.
                        r += p[0] * p[3]
                        g += p[1] * p[3]
                        b += p[2] * p[3]
                        a += p[3]
                if a > 1e-6:
                    out.px[y * w + x] = [r / a, g / a, b / a, a / n]
                else:
                    src = self.px[(y * factor) * self.w + x * factor]
                    out.px[y * w + x] = [src[0], src[1], src[2], 0.0]
        return out

    def bytes_bgra_bottom_up(self):
        data = bytearray()
        for y in range(self.h - 1, -1, -1):
            for x in range(self.w):
                p = self.px[y * self.w + x]
                data += bytes((int(clamp(p[2]) * 255 + 0.5),
                               int(clamp(p[1]) * 255 + 0.5),
                               int(clamp(p[0]) * 255 + 0.5),
                               int(clamp(p[3]) * 255 + 0.5)))
        return bytes(data)

    def bytes_rgba_top_down(self):
        data = bytearray()
        for y in range(self.h):
            for x in range(self.w):
                p = self.px[y * self.w + x]
                data += bytes((int(clamp(p[0]) * 255 + 0.5),
                               int(clamp(p[1]) * 255 + 0.5),
                               int(clamp(p[2]) * 255 + 0.5),
                               int(clamp(p[3]) * 255 + 0.5)))
        return bytes(data)


def write_tga(path, canvas):
    # Sin comprimir, 32 bits, de abajo arriba: el formato que WoW lee sin
    # rechistar. Los dos lados tienen que ser potencia de dos.
    assert canvas.w & (canvas.w - 1) == 0, canvas.w
    assert canvas.h & (canvas.h - 1) == 0, canvas.h
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0,
                         canvas.w, canvas.h, 32, 0x08)
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(canvas.bytes_bgra_bottom_up())
    print("  %-22s %dx%d" % (os.path.basename(path), canvas.w, canvas.h))


def write_png(path, canvas):
    raw = bytearray()
    row = canvas.w * 4
    data = canvas.bytes_rgba_top_down()
    for y in range(canvas.h):
        raw.append(0)
        raw += data[y * row:(y + 1) * row]

    def chunk(tag, payload):
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", canvas.w, canvas.h, 8, 6, 0, 0, 0)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", ihdr))
        fh.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        fh.write(chunk(b"IEND", b""))
    print("  %-22s %dx%d" % (os.path.basename(path), canvas.w, canvas.h))


# --- piezas ----------------------------------------------------------------

def render_glass(size):
    n = size * SS
    aa = 1.4 / n
    c = Canvas(n, n, C_GLASS)
    for py in range(n):
        y = (py + 0.5) / n
        for px in range(n):
            x = (px + 0.5) / n
            i = py * n + px
            outer, inner = flask_sdf(x, y)

            cov_outer = clamp(0.5 - outer / aa)
            if cov_outer <= 0.0:
                continue
            cov_inner = clamp(0.5 - inner / aa)

            # Pared: lo que queda entre la superficie exterior y el interior.
            c.over(i, C_GLASS, cov_outer * (1.0 - cov_inner) * 0.93)

            # Contorno oscuro, para que se lea sobre cualquier fondo.
            ring = cov_outer * (1.0 - clamp(0.5 - (outer + 0.021) / aa))
            c.over(i, C_EDGE, ring * 0.88)

            # Sombra interior pegada a la pared, mas marcada a la derecha.
            if inner < 0.0:
                near = 1.0 - smoothstep(-0.075, 0.0, inner)
                side = clamp(0.20 + 0.80 * (x - 0.5) / 0.32)
                c.over(i, C_EDGE, 0.26 * (1.0 - near) * side)

            # Brillo en media luna, arriba a la izquierda del bulbo.
            arc = abs(sd_circle(x, y, BULB_CX, BULB_CY, 0.252)) - 0.014
            cov_arc = clamp(0.5 - arc / aa)
            if cov_arc > 0.0:
                ang = math.atan2(y - BULB_CY, x - BULB_CX)
                win = 1.0 - smoothstep(0.42, 0.95, abs(ang + 2.42))
                c.over(i, C_WHITE, cov_arc * win * 0.85)

            # Brillo vertical del cuello.
            bar = sd_round_box(x, y, 0.449, 0.300, 0.0115, 0.100, 0.0115)
            c.over(i, C_WHITE, clamp(0.5 - bar / aa) * 0.50)

            # Reflejo del labio.
            shine = sd_round_box(x, y, 0.452, 0.072, 0.045, 0.011, 0.011)
            c.over(i, C_WHITE, clamp(0.5 - shine / aa) * 0.55)

    return c.downsample(SS)


def render_mask(size):
    n = size * SS
    aa = 1.4 / n
    c = Canvas(n, n, C_WHITE)
    for py in range(n):
        y = (py + 0.5) / n
        for px in range(n):
            x = (px + 0.5) / n
            _, inner = flask_sdf(x, y)
            c.px[py * n + px] = [1.0, 1.0, 1.0, clamp(0.5 - inner / aa)]
    return c.downsample(SS)


def gaussian_blur(field, w, h, sigma):
    radius = int(sigma * 3)
    kernel = [math.exp(-(d * d) / (2.0 * sigma * sigma))
              for d in range(-radius, radius + 1)]
    total = sum(kernel)
    kernel = [k / total for k in kernel]

    tmp = [0.0] * (w * h)
    for y in range(h):
        base = y * w
        for x in range(w):
            acc = 0.0
            for j, k in enumerate(kernel):
                sx = min(w - 1, max(0, x + j - radius))
                acc += field[base + sx] * k
            tmp[base + x] = acc

    out = [0.0] * (w * h)
    for y in range(h):
        for x in range(w):
            acc = 0.0
            for j, k in enumerate(kernel):
                sy = min(h - 1, max(0, y + j - radius))
                acc += tmp[sy * w + x] * k
            out[y * w + x] = acc
    return out


def render_glow(size):
    """Silueta encogida, dilatada y difuminada: dibujada a 1/GLOW_SCALE del
    tamano del marco, el halo cae justo por fuera del cristal."""
    n = size
    field = [0.0] * (n * n)
    for py in range(n):
        y = (py + 0.5) / n
        for px in range(n):
            x = (px + 0.5) / n
            # Deshace el encogido para evaluar la silueta a tamano completo.
            sx = 0.5 + (x - 0.5) / GLOW_SCALE
            sy = 0.5 + (y - 0.5) / GLOW_SCALE
            outer, _ = flask_sdf(sx, sy)
            field[py * n + px] = 1.0 - smoothstep(-0.02, 0.085, outer)

    blurred = gaussian_blur(field, n, n, 4.2)
    c = Canvas(n, n, C_WHITE)
    for i, v in enumerate(blurred):
        c.px[i] = [1.0, 1.0, 1.0, clamp(v * 1.25)]
    return c


def render_liquid(w, h):
    """Blanco con un degradado vertical: la superficie, arriba, es lo mas
    claro. Se tine desde Lua con SetVertexColor."""
    c = Canvas(w, h, C_WHITE)
    for y in range(h):
        t = y / float(h - 1)
        v = 1.0 - 0.30 * t * t
        for x in range(w):
            c.px[y * w + x] = [v, v, min(1.0, v * 1.04), 1.0]
    return c


def render_wave(w, h):
    """Banda repetible en horizontal: transparente arriba, opaca abajo y la
    frontera en forma de ola. Los dos armonicos caben un numero entero de
    veces en el ancho, asi que la banda empalma consigo misma sin costura."""
    n_w, n_h = w * SS, h * SS
    c = Canvas(n_w, n_h, C_WHITE)
    for px in range(n_w):
        u = (px + 0.5) / n_w
        surf = (0.5 + 0.22 * math.sin(2 * math.pi * 2 * u)
                + 0.095 * math.sin(2 * math.pi * 3 * u + 1.1))
        for py in range(n_h):
            v = (py + 0.5) / n_h
            cov = clamp((v - surf) * n_h + 0.5)
            # Cresta mas clara, para que se note donde esta la superficie.
            crest = 1.0 - smoothstep(0.0, 0.11, v - surf)
            value = 1.0 + 0.25 * crest
            c.px[py * n_w + px] = [value, value, value, cov]
    return c.downsample(SS)


def render_bubble(size):
    n = size * SS
    aa = 1.4 / n
    c = Canvas(n, n, C_WHITE)
    for py in range(n):
        y = (py + 0.5) / n
        for px in range(n):
            x = (px + 0.5) / n
            i = py * n + px
            d = sd_circle(x, y, 0.5, 0.5, 0.40)
            inside = clamp(0.5 - d / aa)
            if inside <= 0.0:
                continue
            rim = clamp(0.5 - (abs(d + 0.055) - 0.055) / aa)
            c.over(i, C_WHITE, inside * 0.30)
            c.over(i, C_WHITE, rim * 0.80)
            dot = sd_circle(x, y, 0.385, 0.375, 0.085)
            c.over(i, C_WHITE, clamp(0.5 - dot / aa) * 0.85)
    return c.downsample(SS)


# --- montaje, para el icono y la vista previa -------------------------------

WAVE_H = 0.16      # alto de la banda de ola, en fracciones del alto del marco
WAVE_SPAN = 1.6    # cuantas repeticiones de la banda caben de lado a lado
BUBBLES = (        # (x relativo al centro, fase, tamano), los mismos de Display.lua
    (-0.105, 0.00, 0.085),
    (0.070, 0.37, 0.115),
    (-0.020, 0.64, 0.070),
    (0.125, 0.86, 0.095),
)


def sample(tex, u, v, wrap_u=False):
    """Muestreo por vecino mas cercano, que es lo unico que necesita la vista
    previa. Devuelve (r, g, b, a)."""
    if wrap_u:
        u = u % 1.0
    if not (0.0 <= u <= 1.0 and 0.0 <= v <= 1.0):
        return (0.0, 0.0, 0.0, 0.0)
    x = min(tex.w - 1, int(u * tex.w))
    y = min(tex.h - 1, int(v * tex.h))
    return tex.px[y * tex.w + x]


def compose_flask(size, fill, tint, glass, mask, liquid, wave=None, bubble=None,
                  phase=0.0):
    """Monta el matraz igual que el juego: liquido, ola y burbujas recortados
    por la mascara, y el cristal por encima."""
    c = Canvas(size, size, (0.0, 0.0, 0.0))
    top = 1.0 - (FILL_BOTTOM + fill * (FILL_TOP - FILL_BOTTOM))
    bottom = 1.0 - FILL_BOTTOM
    wave_top, wave_bottom = top - WAVE_H / 2.0, top + WAVE_H / 2.0

    for py in range(size):
        y = (py + 0.5) / size
        for px in range(size):
            x = (px + 0.5) / size
            i = py * size + px
            m = mask.px[py * mask.w + px][3]

            if m > 0.0:
                if y > top:
                    t = clamp((y - top) / max(1e-6, bottom - top))
                    shade = liquid.px[int(t * (liquid.h - 1)) * liquid.w][0]
                    c.over(i, (tint[0] * shade, tint[1] * shade,
                               tint[2] * shade), m)

                if wave is not None and wave_top <= y <= wave_bottom:
                    for layer, (span, speed, alpha) in enumerate(
                            ((WAVE_SPAN, 1.0, 0.95), (WAVE_SPAN * 0.7, -0.62, 0.5))):
                        w = sample(wave, x * span + phase * speed,
                                   (y - wave_top) / WAVE_H, wrap_u=True)
                        c.over(i, (tint[0] * w[0], tint[1] * w[1], tint[2] * w[2]),
                               w[3] * alpha * m)

                if bubble is not None and fill > 0.08:
                    for bx, bphase, bsize in BUBBLES:
                        t = (phase * 0.55 + bphase) % 1.0
                        by = bottom - t * (bottom - top)
                        cx = 0.5 + bx + math.sin(t * 6.0 + bphase * 10.0) * 0.018
                        u = (x - (cx - bsize / 2.0)) / bsize
                        v = (y - (by - bsize / 2.0)) / bsize
                        b = sample(bubble, u, v)
                        if b[3] > 0.0:
                            fade = min(1.0, t / 0.12) * (1.0 - smoothstep(0.82, 1.0, t))
                            c.over(i, (1.0, 1.0, 1.0), b[3] * 0.65 * fade * m)

            g = glass.px[i]
            c.over(i, (g[0], g[1], g[2]), g[3])
    return c


def preview(glass, mask, liquid, wave, bubble, glow):
    """Hoja de contactos sobre fondo oscuro, a 2x, para mirarla aqui mismo."""
    size = glass.w
    scale = 2
    cell = size * scale
    pad = int(cell * 0.18)       # sitio para que el halo no se corte
    step = cell + pad
    cols = 4
    width = step * cols + pad
    height = cell + pad * 2
    out = Canvas(width, height)
    for i in range(width * height):
        out.px[i] = [0.07, 0.07, 0.09, 1.0]

    states = [
        (0.12, (0.40, 0.40, 0.46), 0.0, 0.00),   # en reposo (IDLE_FILL)
        (0.42, (0.26, 0.52, 0.98), 0.0, 0.20),   # la regla corriendo
        (0.88, (0.26, 0.52, 0.98), 0.0, 0.65),
        (1.00, (0.35, 0.95, 0.62), 1.0, 0.90),   # regenerando, con brillo
    ]
    for col, (fill, tint, lit, phase) in enumerate(states):
        shot = compose_flask(size, fill, tint, glass, mask, liquid,
                             wave if fill > 0.08 else None,
                             bubble if fill > 0.08 else None, phase)
        ox, oy = pad + col * step, pad

        # El halo se dibuja mas grande que el marco, centrado en el: asi la
        # silueta encogida del TGA vuelve a cuadrar con el cristal.
        if lit > 0.0:
            gsize = int(cell / GLOW_SCALE)
            gx, gy = ox - (gsize - cell) // 2, oy - (gsize - cell) // 2
            for y in range(gsize):
                for x in range(gsize):
                    px_, py_ = gx + x, gy + y
                    if 0 <= px_ < width and 0 <= py_ < height:
                        g = sample(glow, (x + 0.5) / gsize, (y + 0.5) / gsize)
                        out.add(py_ * width + px_, tint, g[3] * lit * 0.85)

        for y in range(cell):
            for x in range(cell):
                p = shot.px[(y // scale) * size + (x // scale)]
                out.over((oy + y) * width + ox + x, (p[0], p[1], p[2]), p[3])
    return out


def main():
    if not os.path.isdir(ART):
        os.makedirs(ART)

    print("Arte del matraz:")
    glass = render_glass(128)
    mask = render_mask(128)
    glow = render_glow(128)
    liquid = render_liquid(32, 64)
    wave = render_wave(64, 32)
    bubble = render_bubble(32)

    write_tga(os.path.join(ART, "FlaskGlass.tga"), glass)
    write_tga(os.path.join(ART, "FlaskMask.tga"), mask)
    write_tga(os.path.join(ART, "FlaskGlow.tga"), glow)
    write_tga(os.path.join(ART, "FlaskLiquid.tga"), liquid)
    write_tga(os.path.join(ART, "FlaskWave.tga"), wave)
    write_tga(os.path.join(ART, "FlaskBubble.tga"), bubble)
    write_tga(os.path.join(ART, "Icon.tga"),
              compose_flask(128, 0.70, (0.26, 0.52, 0.98), glass, mask, liquid,
                            wave, None, 0.3))

    print("Vista previa:")
    write_png(os.path.join(HERE, "preview.png"),
              preview(glass, mask, liquid, wave, bubble, glow))

    # Las mismas piezas en PNG, para montar la vista previa animada en el
    # navegador. No se empaquetan: WoW solo lee los TGA.
    web = os.path.join(HERE, "web")
    if not os.path.isdir(web):
        os.makedirs(web)
    for name, piece in (("glass", glass), ("mask", mask), ("wave", wave),
                        ("bubble", bubble), ("glow", glow)):
        write_png(os.path.join(web, name + ".png"), piece)


if __name__ == "__main__":
    main()
