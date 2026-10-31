"""Grenier et entrepôt « parlants » : une halle au fond, six cases à ciel ouvert devant.

Le sprite du bâtiment montre les cases vides. Pour chaque marchandise acceptée et chaque niveau
de remplissage (1 à 4), on rend à part une case pleine (assets/goods/<bâtiment>_<ressource>_<niveau>.png)
que le jeu pose par-dessus la case, selon le stock (src/presentation/view/storage_view.gd).
La position des cases est partagée avec le jeu dans assets/goods/storage_bays.json.

Les centres des cases sont des multiples de 1/16 de tuile : la case rendue seule tombe alors au pixel
près sur la case du bâtiment.
"""

import json
import math
import os
import random

import bpy

from buildings import BUILDINGS
from kit import (M, T, amphora, awning, blob, crate, cyl, dado, ground_pad, opening, pithos, post, prism_roof,
                 rubble_wall, sphere, tbox, _tile_row)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BAYS_JSON = os.path.join(ROOT, "assets", "goods", "storage_bays.json")
with open(BAYS_JSON) as f:
    BAYS = json.load(f)
HS = BAYS["size"] / 2

# Marchandises de chaque bâtiment (comme "accepts" dans data/buildings.json).
GOODS = {"granary": ["wheat", "fish"], "warehouse": ["olives", "oil", "wool", "wood", "marble"]}


# --------------------------------------------------------------------------- cases (identiques dans le bâtiment et dans la case pleine)

def granary_bin(cx, cy):
    """Coffre à grain : sol de terre battue, murets de brique crue chaulés en haut."""
    x0, y0, x1, y1 = cx - HS, cy - HS, cx + HS, cy + HS
    tbox(x0, y0, 0, x1, y1, 0.012, M("terre_battue", color="#a88a5e", noise=0.12, scale=14))
    brick = M("mudbrick_bin", color="mudbrick", noise=0.08, scale=24)
    lime = M("chaux", color="#ece3cf", noise=0.04)
    t, h = 0.04, 0.07
    for (a0, b0, a1, b1) in ((x0, y0, x1, y0 + t), (x0, y1 - t, x1, y1), (x0, y0, x0 + t, y1), (x1 - t, y0, x1, y1)):
        tbox(a0, b0, 0, a1, b1, h, brick)
        tbox(a0 - 0.004, b0 - 0.004, h, a1 + 0.004, b1 + 0.004, h + 0.012, lime)


def warehouse_bay(cx, cy):
    """Travée d'entrepôt : dallage de pierre, poteaux d'angle et lisses de bois."""
    x0, y0, x1, y1 = cx - HS, cy - HS, cx + HS, cy + HS
    tbox(x0, y0, 0, x1, y1, 0.012, M("stone_bay", color="#b9ad96", kind="brick", scale=26))
    wood = M("wood_bay", color="wood", noise=0.06)
    for (px, py) in ((x0 + 0.02, y0 + 0.02), (x1 - 0.02, y0 + 0.02), (x0 + 0.02, y1 - 0.02), (x1 - 0.02, y1 - 0.02)):
        tbox(px - 0.018, py - 0.018, 0.012, px + 0.018, py + 0.018, 0.14, wood)
    for (a0, b0, a1, b1) in ((x0 + 0.02, y0 + 0.012, x1 - 0.02, y0 + 0.028), (x0 + 0.02, y1 - 0.028, x1 - 0.02, y1 - 0.012),
                             (x0 + 0.012, y0 + 0.02, x0 + 0.028, y1 - 0.02), (x1 - 0.028, y0 + 0.02, x1 - 0.012, y1 - 0.02)):
        tbox(a0, b0, 0.1, a1, b1, 0.118, wood)


BAY = {"granary": granary_bin, "warehouse": warehouse_bay}


# --------------------------------------------------------------------------- marchandises, niveau 1 (un quart) à 4 (plein)

def _grid(cx, cy, n, cols, step):
    pts = []
    rows = math.ceil(n / cols)
    for k in range(n):
        r, c = divmod(k, cols)
        pts.append((cx + (c - (cols - 1) / 2) * step, cy + (r - (rows - 1) / 2) * step))
    return pts


def wheat(cx, cy, lv, rnd):
    """Tas de blé doré qui monte, puis des sacs autour quand le coffre déborde."""
    m = M("ble_tas", color="wheat", noise=0.22, scale=30, bump=0.4)
    r = 0.14 + 0.05 * lv
    blob(cx, cy, 0.012, r, m, seed=lv, sz=0.03 + 0.035 * lv, lumps=0.15)
    if lv >= 2:
        blob(cx - 0.12, cy + 0.08, 0.012, r * 0.55, m, seed=lv + 9, sz=0.02 + 0.02 * lv, lumps=0.15)
    if lv >= 3:
        sac = M("sac", color="#d8c39a", noise=0.12, bump=0.3)
        for (x, y) in ((cx + 0.22, cy + 0.22), (cx + 0.1, cy + 0.25), (cx + 0.24, cy + 0.08))[: lv - 1]:
            sphere(x, y, 0.05, 0.05, sac, sz=0.045)
    if lv == 4:
        blob(cx + 0.03, cy - 0.03, 0.1, 0.12, m, seed=31, sz=0.07, lumps=0.12)


def _basket(x, y, fill, seed, kind):
    wicker = M("osier", color="#9a7448", noise=0.2, scale=60, bump=0.6)
    cyl(x, y, 0.012, 0.08, 0.08, wicker, verts=16, r_top=0.092)
    rnd = random.Random(seed)
    if kind == "fish":
        fish = [M("poisson", color="#d4dde0", rough=0.3, noise=0.1), M("poisson2", color="#a9bcc6", rough=0.3, noise=0.1)]
        sphere(x, y, 0.078, 0.082, M("paille", color="#c9b27a", noise=0.15), sz=0.012)
        for k in range(5):
            a = rnd.uniform(0, math.pi)
            bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.07,
                                                 location=(x + rnd.uniform(-0.03, 0.03), -y + rnd.uniform(-0.03, 0.03), 0.09 + k * 0.008))
            o = bpy.context.object
            o.scale = (1.0, 0.3, 0.2)
            o.rotation_euler = (0, 0, a)
            o.data.materials.append(rnd.choice(fish))
    else:
        sphere(x, y, 0.082, 0.082, M(fill, color=fill, noise=0.3, scale=110, bump=1.0), sz=0.035)


def fish(cx, cy, lv, rnd):
    """Paniers de poissons argentés ; au plein, des poissons pendus à un séchoir."""
    n = (2, 4, 6, 9)[lv - 1]
    for k, (x, y) in enumerate(_grid(cx, cy, n, 3, 0.205)):
        _basket(x, y, None, lv * 10 + k, "fish")
    if lv == 4:
        wood = M("wood")
        post(cx - 0.3, cy - 0.3, 0.012, 0.2)
        post(cx + 0.3, cy - 0.3, 0.012, 0.2)
        tbox(cx - 0.31, cy - 0.31, 0.19, cx + 0.31, cy - 0.29, 0.205, wood)


def olives(cx, cy, lv, rnd):
    """Paniers débordant d'olives noires et vertes."""
    n = (2, 4, 6, 9)[lv - 1]
    for k, (x, y) in enumerate(_grid(cx, cy, n, 3, 0.205)):
        _basket(x, y, "#3b3a24" if k % 3 else "#6d7a35", lv * 10 + k, "olives")


def oil(cx, cy, lv, rnd):
    """Amphores d'huile au col noir, debout en rangs."""
    n = (3, 6, 9, 12)[lv - 1]
    clay = M("amphore_huile", color="#c99a6a", noise=0.08)
    neck = M("vernis_noir", color="#2a2420", rough=0.4, noise=0.03)
    for (x, y) in _grid(cx, cy, n, 4, 0.155):
        sphere(x, y, 0.09, 0.055, clay, sz=0.08, seg=14, rings=8)
        cyl(x, y, 0.012, 0.035, 0.02, clay, verts=10)
        cyl(x, y, 0.15, 0.21, 0.019, neck, verts=10)
        cyl(x, y, 0.21, 0.222, 0.028, neck, verts=10)


def wool(cx, cy, lv, rnd):
    """Toisons de laine écrue roulées en boules duveteuses, quelques-unes teintes, en tas qui grossit."""
    m = M("toison", color="#f3e9cf", noise=0.18, bump=1.2, scale=70)
    dyed = M("toison_teinte", color="#b0483a", noise=0.15, bump=1.0, scale=70)
    spots = [(-0.15, -0.15), (0.15, -0.15), (-0.15, 0.15), (0.15, 0.15), (0.0, 0.0), (-0.08, 0.0), (0.08, 0.0), (0.0, 0.08)]
    n = (2, 4, 6, 8)[lv - 1]
    for k in range(n):
        dx, dy = spots[k]
        z = 0.012 if k < 4 else 0.1
        blob(cx + dx, cy + dy, z + 0.06, 0.12, dyed if k == 2 else m, seed=40 + k, sz=0.075, lumps=0.3)


def wood(cx, cy, lv, rnd):
    """Pile de rondins qui monte d'une couche par niveau."""
    bark = M("ecorce", color="#6e4a2c", noise=0.2, scale=50, bump=0.5)
    cut = M("aubier", color="#d8b27a", noise=0.1)
    r = 0.04
    for layer in range(lv):
        count = 6 - layer
        for k in range(count):
            y = cy + (k - (count - 1) / 2) * (2 * r + 0.004)
            z = 0.012 + r + layer * (2 * r * 0.87)
            bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=r, depth=0.56, location=(cx, -y, z))
            o = bpy.context.object
            o.rotation_euler = (0, math.radians(90), 0)
            o.data.materials.append(bark)
            # Bout scié visible (face x max).
            bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=r * 0.85, depth=0.006, location=(cx + 0.281, -y, z))
            o = bpy.context.object
            o.rotation_euler = (0, math.radians(90), 0)
            o.data.materials.append(cut)


def marble(cx, cy, lv, rnd):
    """Blocs de marbre équarris ; au-delà de quatre, on les empile."""
    m = M("bloc_marbre", color="#f4f2ee", noise=0.12, scale=12, bump=0.2)
    spots = [(-0.14, -0.14), (0.14, -0.14), (-0.14, 0.14), (0.14, 0.14), (-0.07, 0.0), (0.12, 0.0)]
    n = (1, 2, 4, 6)[lv - 1]
    for k in range(n):
        dx, dy = spots[k]
        z = 0.012 if k < 4 else 0.152
        s = 0.11 if k < 4 else 0.09
        tbox(cx + dx - s, cy + dy - s * 0.85, z, cx + dx + s, cy + dy + s * 0.85, z + 0.14, m, bevel=0.01)


FILL = {"wheat": wheat, "fish": fish, "olives": olives, "oil": oil, "wool": wool, "wood": wood, "marble": marble}


# --------------------------------------------------------------------------- bâtiments

def _bays(name):
    for (cx, cy) in BAYS["buildings"][name]:
        BAY[name](cx, cy)


def granary():
    """Grenier : halle chaulée sur soubassement ventilé, toit de tuiles, six coffres à grain devant."""
    ground_pad(3, "dirt", seed=3)
    stone = M("stone_soc", color="stone", kind="brick", scale=22)
    tbox(0.15, 0.12, 0, 2.85, 1.12, 0.12, stone)
    for x in (0.35, 0.75, 1.15, 1.85, 2.25, 2.65):
        tbox(x - 0.04, 1.11, 0.04, x + 0.04, 1.125, 0.09, M("black", color="#2a2018", noise=0.0))
    tbox(0.17, 0.14, 0.12, 2.83, 1.1, 0.62, M("plaster_warm", color="plaster_warm", noise=0.06))
    dado(("y", 1.1), 0.17, 2.83, 0.12, 0.2, "#a8382c")
    dado(("x", 2.83), 0.14, 1.1, 0.12, 0.2, "#a8382c")
    opening(("y", 1.1), 1.5, 0.12, 0.12, 0.46, kind="door")
    for x in (0.45, 0.95, 2.05, 2.55):
        opening(("y", 1.1), x, 0.035, 0.42, 0.54, shutters=False)
    opening(("x", 2.83), 0.62, 0.1, 0.12, 0.44, kind="door")
    # Épis de blé peints au-dessus de la porte.
    for k in range(3):
        tbox(1.42 + k * 0.08, 1.1, 0.5, 1.45 + k * 0.08, 1.108, 0.58, M("ocre_peint", color="ochre", noise=0.05))
    prism_roof(0.15, 0.12, 2.85, 1.12, 0.62, 0.36, along="x", pediment=M("plaster_warm"))
    # Lanterneau d'aération sur le faîte.
    tbox(1.2, 0.55, 0.96, 1.8, 0.69, 1.04, M("plaster_warm"))
    _tile_row(T(1.17, 0.62, 1.05), T(1.83, 0.62, 1.05), 0.03, M("terracotta"))
    # Vie autour : sacs près de la porte, jarres, balance, poules.
    for k in range(3):
        sphere(1.12 + k * 0.08, 1.2, 0.05, 0.045, M("sac", color="#d8c39a", noise=0.12, bump=0.3), sz=0.04)
    pithos(2.92, 0.3, s=0.7)
    pithos(2.92, 0.46, s=0.6)
    rubble_wall(0.05, 0.05, 0.05, 1.1, h=0.08, seed=5)
    _bays("granary")


def warehouse():
    """Entrepôt : halle de pierre à grande porte, poulie de chargement, six travées ouvertes devant."""
    ground_pad(3, "dirt", seed=4)
    tbox(0.15, 0.12, 0, 2.85, 1.12, 0.1, M("stone_soc", color="stone", kind="brick", scale=22))
    wall = M("stone_mur", color="#cbbd9f", kind="brick", scale=16)
    tbox(0.17, 0.14, 0.1, 2.83, 1.1, 0.62, wall)
    opening(("y", 1.1), 1.5, 0.2, 0.1, 0.5, kind="door")
    for x in (0.5, 0.9, 2.1, 2.5):
        opening(("y", 1.1), x, 0.035, 0.44, 0.54, shutters=False)
    opening(("x", 2.83), 0.62, 0.12, 0.1, 0.46, kind="door")
    prism_roof(0.15, 0.12, 2.85, 1.12, 0.62, 0.34, along="x", pediment=wall)
    # Potence et poulie au-dessus de la grande porte.
    wood = M("wood")
    tbox(1.48, 0.95, 0.6, 1.52, 1.24, 0.64, wood)
    cyl(1.5, 1.21, 0.5, 0.6, 0.004, M("corde", color="#8a6a40", noise=0.05))
    crate(1.5, 1.2, 0.42, s=0.08)
    # Auvent sur le côté droit, jarres et caisses en attente.
    for x in (2.35, 2.8):
        post(x, 1.26, 0, 0.34)
    awning(2.3, 1.1, 2.85, 1.28, 0.42, 0.34, along="x", colors=("terracotta", "terracotta_dark"), stripes=6)
    for k in range(3):
        amphora(2.93, 0.3 + k * 0.12, s=0.8)
    crate(0.3, 1.22, s=0.1)
    crate(0.42, 1.22, s=0.09)
    _bays("warehouse")


BUILDINGS["granary"] = (granary, 3)
BUILDINGS["warehouse"] = (warehouse, 3)


def goods_jobs():
    """(nom, fonction de scène) de chaque case pleine à rendre."""
    jobs = []
    for b, resources in GOODS.items():
        for res in resources:
            for lv in range(1, 5):
                def scene(b=b, res=res, lv=lv):
                    BAY[b](0.5, 0.5)
                    FILL[res](0.5, 0.5, lv, random.Random(lv))
                jobs.append(("%s_%s_%d" % (b, res, lv), scene))
    return jobs
