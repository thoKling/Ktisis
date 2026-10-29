"""Sols et routes, peints en 2D (numpy + Pillow) : python terrain.py

Les sols sont des motifs périodiques sur K x K tuiles, découpés en K² variantes :
la tuile (x, y) utilise la variante (x mod K, y mod K), les raccords sont donc invisibles.
Sorties en 2x (128 x 64), comme les bâtiments.
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "terrain")
K = 4
HW, HH = 64, 32          # demi-largeur, demi-hauteur d'une tuile en pixels (2x)
SS = 2                   # suréchantillonnage


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


# --------------------------------------------------------------------------- bruit périodique

def periodic_noise(n, period, octaves, seed):
    """Bruit de valeurs périodique sur une grille n x n couvrant `period` tuiles."""
    rnd = np.random.default_rng(seed)
    total = np.zeros((n, n), np.float32)
    amp, norm = 1.0, 0.0
    freq = period
    for _ in range(octaves):
        g = rnd.random((freq, freq)).astype(np.float32)
        t = np.arange(n) * freq / n
        i0 = np.floor(t).astype(int)
        f = t - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % freq
        a = g[np.ix_(i0, i0)] * (1 - f)[None, :] + g[np.ix_(i0, i1)] * f[None, :]
        b = g[np.ix_(i1, i0)] * (1 - f)[None, :] + g[np.ix_(i1, i1)] * f[None, :]
        total += amp * (a * (1 - f)[:, None] + b * f[:, None])
        norm += amp
        amp *= 0.5
        freq *= 2
    return total / norm


class Field:
    """Fonction périodique (u, v) -> valeur, échantillonnée sur une grille fine."""

    def __init__(self, octaves=4, seed=0, period=K, res=256):
        self.res = res
        self.g = periodic_noise(res, period, octaves, seed)

    def __call__(self, u, v):
        i = (np.floor(u / K * self.res).astype(int)) % self.res
        j = (np.floor(v / K * self.res).astype(int)) % self.res
        return self.g[j, i]


# --------------------------------------------------------------------------- grand patch iso

def patch_coords():
    """Coordonnées (u, v) de chaque pixel d'un grand patch couvrant K x K tuiles avec une marge."""
    w = (2 * K + 2) * HW * SS
    h = (2 * K + 2) * HH * SS
    ox = w / 2
    oy = HH * SS * 1.0
    xs, ys = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    sx = (xs - ox) / SS
    sy = (ys - oy) / SS
    u = (sx / HW + sy / HH) / 2
    v = (sy / HH - sx / HW) / 2
    return u, v, (ox, oy), (w, h)


def to_px(u, v, origin):
    ox, oy = origin
    return ox + (u - v) * HW * SS, oy + (u + v) * HH * SS


def cut_tiles(img, origin, name, extra=None):
    """Découpe les K² tuiles d'un patch et les enregistre (losange élargi d'1 px pour éviter les joints)."""
    os.makedirs(OUT, exist_ok=True)
    big = img.resize((img.width // SS, img.height // SS), Image.LANCZOS)
    mask = diamond_mask()
    for j in range(K):
        for i in range(K):
            px, py = to_px(i, j, origin)
            x0, y0 = int(round(px / SS)) - HW, int(round(py / SS))
            tile = big.crop((x0, y0, x0 + 2 * HW, y0 + 2 * HH)).convert("RGBA")
            tile.putalpha(mask)
            tile.save(os.path.join(OUT, "%s_%d.png" % (name, j * K + i)))


def diamond_mask(grow=1.2):
    xs, ys = np.meshgrid(np.arange(2 * HW) + 0.5, np.arange(2 * HH) + 0.5)
    d = np.abs(xs - HW) / HW + np.abs(ys - HH) / HH
    a = np.clip((1 + grow / HH - d) * HH, 0, 1)
    return Image.fromarray((a * 255).astype(np.uint8))


def paint(u, v, colors, field, contrast=1.0):
    """Mélange de couleurs selon un champ de bruit (aplats doux, aspect peint)."""
    f = field(u, v)
    f = np.clip((f - 0.5) * contrast + 0.5, 0, 1)
    n = len(colors) - 1
    idx = np.clip(f * n, 0, n - 1e-4)
    i = np.floor(idx).astype(int)
    t = (idx - i)[..., None]
    t = t * t * (3 - 2 * t)
    cols = np.stack([rgb(c) for c in colors])
    return cols[i] * (1 - t) + cols[i + 1] * t


def wrapped(points):
    """Copies d'un point du tore aux 9 positions, pour dessiner à travers les bords du patch."""
    for (u, v) in points:
        for du in (-K, 0, K):
            for dv in (-K, 0, K):
                yield u + du, v + dv


def strokes(img, origin, rnd, count, colors, length=(3, 6), width=1, slant=0.3, area=None):
    d = ImageDraw.Draw(img)
    pts = [(rnd.uniform(0, K), rnd.uniform(0, K)) for _ in range(count)]
    for k, (u, v) in enumerate(wrapped(pts)):
        c = colors[(k // 9) % len(colors)]
        if area is not None and not area(u % K, v % K):
            continue
        x, y = to_px(u, v, origin)
        L = rnd.uniform(*length) * SS
        dx = rnd.uniform(-slant, slant) * L
        d.line((x, y, x + dx, y - L), fill=c, width=width * SS)


def dots(img, origin, rnd, count, colors, r=(1, 2)):
    d = ImageDraw.Draw(img)
    pts = [(rnd.uniform(0, K), rnd.uniform(0, K)) for _ in range(count)]
    for k, (u, v) in enumerate(wrapped(pts)):
        c = colors[(k // 9) % len(colors)]
        x, y = to_px(u, v, origin)
        rr = rnd.uniform(*r) * SS
        d.ellipse((x - rr, y - rr * 0.6, x + rr, y + rr * 0.6), fill=c)


# --------------------------------------------------------------------------- sols

def grass(name="0", base=("#869548", "#93a252", "#9fad5a", "#aab463"), seed=1, flowers=("#f1e6c4", "#d9c34f"),
          blade=("#6c7b3a", "#5d6c31", "#b9c26f"), nflowers=40):
    u, v, origin, size = patch_coords()
    col = paint(u, v, list(base), Field(5, seed), contrast=1.1)
    shade = Field(3, seed + 50)(u, v)[..., None]
    col *= 0.94 + shade * 0.1
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    rnd = random.Random(seed)
    strokes(img, origin, rnd, 900, list(blade), length=(2, 5))
    dots(img, origin, rnd, nflowers, list(flowers), r=(0.8, 1.4))
    cut_tiles(img, origin, name)


def meadow():
    grass("4", base=("#a9b45a", "#b9c164", "#c8c873", "#d2c77a"), seed=4,
          blade=("#94a04a", "#c9c27a", "#e0d68c"), flowers=("#f4ecd0", "#e4b84b", "#c96a8a"), nflowers=160)


def forest_floor():
    grass("2", base=("#55692f", "#617636", "#6e823e", "#7a8a45"), seed=2,
          blade=("#46582a", "#3f5026", "#82924c"), flowers=("#9a8355",), nflowers=60)


def rock_ground():
    u, v, origin, size = patch_coords()
    col = paint(u, v, ["#9a907d", "#ada391", "#bdb3a0", "#a59a85"], Field(5, 3), contrast=1.8)
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    rnd = random.Random(3)
    dots(img, origin, rnd, 260, ["#8c826f", "#c9c0ad", "#7d7464"], r=(0.8, 2.2))
    strokes(img, origin, rnd, 200, ["#7f8a48", "#8f9a52"], length=(2, 3))
    cut_tiles(img, origin, "3")


def hill_ground():
    """Colline sacrée : calcaire blanchi par le soleil, dalles fendues, touffes d'herbe sèche."""
    u, v, origin, size = patch_coords()
    col = paint(u, v, ["#c9b993", "#d6c7a2", "#e2d5b3", "#d9c9a1"], Field(5, 11), contrast=1.5)
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    rnd = random.Random(11)
    # Fissures du rocher : courts traits brisés.
    pts = [(rnd.uniform(0, K), rnd.uniform(0, K)) for _ in range(70)]
    for k, (uu, vv) in enumerate(wrapped(pts)):
        x, y = to_px(uu, vv, origin)
        c = (168, 150, 116) if (k // 9) % 2 else (186, 170, 136)
        pts2 = [(x, y)]
        for _ in range(3):
            x += rnd.uniform(-7, 7) * SS
            y += rnd.uniform(-3, 3) * SS
            pts2.append((x, y))
        d.line(pts2, fill=c, width=SS)
    dots(img, origin, rnd, 220, ["#bcab85", "#efe6cf", "#a99a78"], r=(0.7, 1.8))
    strokes(img, origin, rnd, 260, ["#9a9a58", "#b0a764", "#8a8a4c"], length=(2, 4))
    cut_tiles(img, origin, "5")


def water():
    u, v, origin, size = patch_coords()
    col = paint(u, v, ["#2c6a98", "#3477a6", "#3d84b2", "#468fba"], Field(4, 9), contrast=1.5)
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    rnd = random.Random(9)
    pts = [(rnd.uniform(0, K), rnd.uniform(0, K)) for _ in range(70)]
    for k, (uu, vv) in enumerate(wrapped(pts)):
        x, y = to_px(uu, vv, origin)
        L = rnd.uniform(4, 9) * SS
        c = (196, 224, 238) if (k // 9) % 3 else (150, 196, 222)
        d.arc((x - L, y - L * 0.35, x + L, y + L * 0.35), 200, 340, fill=c, width=SS)
    cut_tiles(img, origin, "1")


# --------------------------------------------------------------------------- rivages

def shores():
    """Bande de sable et d'écume le long d'un bord du losange d'eau qui touche la terre.

    shore_<b>.png : b = 1 voisin x+1, 2 voisin x-1, 4 voisin y+1, 8 voisin y-1 (comme les routes).
    """
    W, H = 2 * HW * SS, 2 * HH * SS
    xs, ys = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    sx, sy = (xs - W / 2) / SS, ys / SS
    u = (sx / HW + sy / HH) / 2
    v = (sy / HH - sx / HW) / 2
    nz = Field(4, 21)
    for bit, dist in ((1, 1 - u), (2, u), (4, 1 - v), (8, v)):
        along = v if bit in (1, 2) else u
        wob = (nz(along * 4, np.full_like(along, bit)) - 0.5) * 0.08
        dd = dist + wob
        sand = np.clip((0.14 - dd) / 0.03, 0, 1)
        foam = np.clip(1 - np.abs(dd - 0.17) / 0.025, 0, 1) * 0.85
        shallow = np.clip((0.45 - dd) / 0.3, 0, 1) * 0.5
        inside = (np.abs(sx) / HW + np.abs(sy - HH) / HH) <= 1.0 + 1.0 / HH
        col = np.zeros((H, W, 4), np.float32)
        for c, a in ((rgb("#79b9cc"), shallow), (rgb("#eef4f2"), foam), (rgb("#d9c48f"), sand)):
            a = a[..., None]
            na = a + col[..., 3:] * (1 - a)
            col[..., :3] = (c * a + col[..., :3] * col[..., 3:] * (1 - a)) / np.maximum(na, 1e-4)
            col[..., 3:] = na
        col[..., 3] *= inside * 255
        img = Image.fromarray(col.astype(np.uint8), "RGBA").resize((2 * HW, 2 * HH), Image.LANCZOS)
        img.save(os.path.join(OUT, "shore_%d.png" % bit))


# --------------------------------------------------------------------------- routes

def roads():
    """Voie dallée bordée de terre battue. road_<masque>.png, masque = 1 x+ / 2 x- / 4 y+ / 8 y-."""
    out = os.path.join(ROOT, "assets", "roads")
    os.makedirs(out, exist_ok=True)
    W, H = 2 * HW * SS, 2 * HH * SS
    xs, ys = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    sx, sy = (xs - W / 2) / SS, ys / SS
    u = (sx / HW + sy / HH) / 2
    v = (sy / HH - sx / HW) / 2
    inside = (np.abs(sx) / HW + np.abs(sy - HH) / HH) <= 1.0 + 1.0 / HH
    rnd = np.random.default_rng(5)
    # Dalles : grille décalée en tuile, couleur par dalle.
    slab_c = rnd.random((8, 8))
    nz = Field(4, 31)

    def region(mask, half):
        r = (np.abs(u - 0.5) <= half) & (np.abs(v - 0.5) <= half)
        if mask & 1:
            r |= (u >= 0.5) & (np.abs(v - 0.5) <= half)
        if mask & 2:
            r |= (u <= 0.5) & (np.abs(v - 0.5) <= half)
        if mask & 4:
            r |= (v >= 0.5) & (np.abs(u - 0.5) <= half)
        if mask & 8:
            r |= (v <= 0.5) & (np.abs(u - 0.5) <= half)
        return r

    for mask in range(16):
        edge = region(mask, 0.4) & inside
        pave = region(mask, 0.3) & inside
        col = np.zeros((H, W, 4), np.float32)
        dirt = np.stack([rgb("#b49a6c")] * 1)[0] * (0.92 + nz(u * 2, v * 2)[..., None] * 0.16)
        col[..., :3] = dirt
        col[..., 3] = edge * 255
        # Dalles irrégulières : rangées décalées.
        gu, gv = u * 4, v * 6
        row = np.floor(gv).astype(int)
        gu2 = gu + (row % 2) * 0.5
        cell = np.floor(gu2).astype(int)
        fu, fv = gu2 - cell, gv - row
        joint = (fu < 0.08) | (fv < 0.1)
        shade = slab_c[row % 8, cell % 8][..., None]
        stone = rgb("#ddd2bb") * (0.9 + shade * 0.14)
        stone = np.where(joint[..., None], rgb("#9f9076"), stone)
        col[..., :3] = np.where(pave[..., None], stone, col[..., :3])
        # Bordure : liseré sombre entre dalles et terre.
        border = region(mask, 0.32) & ~pave & inside
        col[..., :3] = np.where(border[..., None], rgb("#8e7c5c"), col[..., :3])
        img = Image.fromarray(col.astype(np.uint8), "RGBA").resize((2 * HW, 2 * HH), Image.LANCZOS)
        img.save(os.path.join(out, "road_%d.png" % mask))


if __name__ == "__main__":
    import sys
    steps = {"grass": grass, "meadow": meadow, "forest": forest_floor, "rock": rock_ground, "hill": hill_ground,
             "water": water, "shores": shores, "roads": roads}
    for name in sys.argv[1:] or steps:
        steps[name]()
    print("ok terrain")
