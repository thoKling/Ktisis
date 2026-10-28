"""Les cinq niveaux de maison et la parcelle vide (taille 2).

Faces visibles : y max (gauche de l'écran) et x max (droite). On y met portes, fenêtres, balcons.
"""

import random

from buildings import building
from kit import (M, T, amphora, balcony, blob, bush, chicken, colonnade, cyl, cypress, dado, laundry, mesh,
                 olive_tree, opening, oven, paving, pebbles, pergola, pithos, post, potted_plant, prism_roof,
                 rubble_wall, sphere, statue, tbox, tufts, water_surface, well)


def walls(x0, y0, x1, y1, h, wall="plaster", base="#9b8f7a", band=None):
    """Murs enduits sur un socle de moellons, bande peinte optionnelle en bas des faces visibles."""
    tbox(x0 - 0.01, y0 - 0.01, 0, x1 + 0.01, y1 + 0.01, 0.06, M("socle", color=base, kind="brick", scale=34))
    tbox(x0, y0, 0.06, x1, y1, h, M(wall, color=wall, noise=0.08, scale=14))
    if band:
        from kit import dado as _d
        _d(("y", y1), x0, x1, 0.06, 0.13, band)
        _d(("x", x1), y0, y1, 0.06, 0.13, band)


def ground(seed, color="dirt"):
    tbox(0.02, 0.02, 0, 1.98, 1.98, 0.008, M("sol_" + color, color=color, noise=0.18, scale=6))
    tufts(0.05, 1.75, 1.95, 1.95, 7, seed)
    tufts(1.75, 0.05, 1.95, 1.95, 7, seed + 1)
    pebbles(0.1, 0.1, 1.9, 1.9, 8, seed)


def thatch_roof(x0, y0, x1, y1, z, rise, along="x", seed=0):
    th = M("thatch", color="thatch", noise=0.22, scale=30, bump=0.6)
    prism_roof(x0, y0, x1, y1, z, rise, along=along, material=th, overhang=0.11, tiles=False)
    rnd = random.Random(seed)
    # Faîtage en bottes de paille et bords effilochés.
    if along == "x":
        ym = (y0 + y1) / 2
        for k in range(int((x1 - x0) / 0.09) + 1):
            blob(x0 - 0.05 + k * 0.09, ym, z + rise + 0.01, 0.05, M("thatch_dark", color="#b0904a", noise=0.2), seed=seed + k, sz=0.03)
    else:
        xm = (x0 + x1) / 2
        for k in range(int((y1 - y0) / 0.09) + 1):
            blob(xm, y0 - 0.05 + k * 0.09, z + rise + 0.01, 0.05, M("thatch_dark", color="#b0904a", noise=0.2), seed=seed + k, sz=0.03)
    for k in range(6):
        cyl(x0 + rnd.uniform(0, x1 - x0), y1 + 0.1, z - 0.04, z + 0.01, 0.004, th, verts=4)


def wattle(tx0, ty0, tx1, ty1, h=0.14):
    """Clôture de branches tressées."""
    n = int(max(abs(tx1 - tx0), abs(ty1 - ty0)) / 0.12) + 1
    for i in range(n + 1):
        f = i / n
        post(tx0 + (tx1 - tx0) * f, ty0 + (ty1 - ty0) * f, 0, h + 0.02, r=0.008, material="wood_dark")
    for z in (h * 0.4, h * 0.75):
        if abs(tx1 - tx0) > abs(ty1 - ty0):
            tbox(tx0, ty0 - 0.006, z, tx1, ty0 + 0.006, z + 0.03, M("osier", color="#9a7a4a", noise=0.15, bump=0.4), bevel=0.004)
        else:
            tbox(tx0 - 0.006, ty0, z, tx0 + 0.006, ty1, z + 0.03, M("osier", color="#9a7a4a", noise=0.15, bump=0.4), bevel=0.004)


@building("house_empty", 2)
def house_empty():
    """Parcelle libre : piquets, cordeau, briques crues et outils en attendant les colons."""
    ground(5)
    for (x, y) in ((0.25, 0.25), (1.75, 0.25), (0.25, 1.75), (1.75, 1.75)):
        post(x, y, 0, 0.16, r=0.012)
    for (a, b) in (((0.25, 0.25), (1.75, 0.25)), ((1.75, 0.25), (1.75, 1.75)), ((1.75, 1.75), (0.25, 1.75)), ((0.25, 1.75), (0.25, 0.25))):
        tbox(min(a[0], b[0]) - 0.003, min(a[1], b[1]) - 0.003, 0.13, max(a[0], b[0]) + 0.003, max(a[1], b[1]) + 0.003, 0.136, M("corde", color="#e8dcc0"))
    for k in range(9):
        tbox(0.55 + (k % 3) * 0.1, 0.9, (k // 3) * 0.045, 0.64 + (k % 3) * 0.1, 1.08, 0.04 + (k // 3) * 0.045, M("mudbrick", color="mudbrick", noise=0.1))
    tbox(1.1, 1.1, 0.008, 1.4, 1.4, 0.02, M("boue", color="#8a6a48", noise=0.2))
    post(1.3, 0.6, 0, 0.22, r=0.008)
    pithos(1.4, 1.5, s=0.8)


@building("house_0", 2)
def hut():
    """Hutte : brique crue et chaume, clôture tressée, foyer, poules et jarres."""
    ground(1)
    walls(0.3, 0.25, 1.25, 1.1, 0.3, wall="mudbrick", base="#8f8472")
    opening(("x", 1.25), 0.68, 0.06, 0.06, 0.25, kind="door")
    opening(("y", 1.1), 0.75, 0.035, 0.17, 0.24, shutters=False)
    thatch_roof(0.3, 0.25, 1.25, 1.1, 0.3, 0.32, seed=1)
    # Appentis de branches et tas de bois.
    for (x, y) in ((1.35, 0.25), (1.65, 0.25), (1.35, 0.6), (1.65, 0.6)):
        post(x, y, 0, 0.2 if y > 0.4 else 0.24, r=0.01)
    tbox(1.3, 0.2, 0.22, 1.7, 0.65, 0.24, M("thatch", color="thatch", noise=0.2, bump=0.5))
    for k in range(6):
        cyl(1.42 + (k % 3) * 0.07, 0.42, 0.0 + (k // 3) * 0.05, 0.05 + (k // 3) * 0.05, 0.022, M("wood"), verts=6)
    wattle(0.2, 1.85, 1.85, 1.85)
    wattle(1.85, 0.9, 1.85, 1.85)
    # Foyer de pierres et marmite.
    for k in range(7):
        import math
        a = k / 7 * 6.283
        blob(0.75 + 0.07 * math.cos(a), 1.45 + 0.07 * math.sin(a), 0.01, 0.025, M("caillou", color="#8f8472"), seed=k, sz=0.02)
    cyl(0.75, 1.45, 0.02, 0.08, 0.04, M("marmite", color="#3a3028"), verts=10)
    pithos(1.45, 1.05)
    pithos(1.55, 1.2, s=0.8)
    for (x, y, c) in ((1.2, 1.5, "#efe4cf"), (1.35, 1.6, "#a0623a"), (1.1, 1.65, "#efe4cf")):
        chicken(x, y, color=c)
    tbox(0.35, 1.25, 0.008, 0.55, 1.6, 0.03, M("soil", color="soil", noise=0.2))
    for k in range(3):
        bush(0.45, 1.3 + k * 0.12, 0.02, 0.5, seed=k, color="olive")


@building("house_1", 2)
def house_simple():
    """Maison simple : corps enduit à toit de tuiles, appentis, cour avec four et corde à linge."""
    ground(2)
    walls(0.12, 0.12, 1.3, 0.95, 0.42, band="#c9a24c")
    opening(("y", 0.95), 0.45, 0.06, 0.06, 0.29, kind="door")
    opening(("y", 0.95), 0.95, 0.04, 0.2, 0.3, color="#3c6e9a")
    opening(("x", 1.3), 0.5, 0.04, 0.2, 0.3, color="#3c6e9a")
    prism_roof(0.12, 0.12, 1.3, 0.95, 0.42, 0.28, along="x", pediment=M("plaster"))
    walls(1.3, 0.2, 1.8, 0.75, 0.3, wall="plaster_warm")
    opening(("x", 1.8), 0.48, 0.055, 0.06, 0.24, kind="door")
    prism_roof(1.3, 0.2, 1.8, 0.75, 0.3, 0.16, along="y", pediment=M("plaster_warm"))
    rubble_wall(0.1, 1.88, 1.88, 1.88, h=0.13, seed=2)
    rubble_wall(1.88, 0.85, 1.88, 1.88, h=0.13, seed=3)
    oven(0.35, 1.45)
    pithos(1.55, 1.05)
    amphora(1.65, 1.15, s=0.9)
    laundry(0.75, 1.3, 1.5, 1.3, z=0.26, seed=1)
    chicken(1.0, 1.6)
    potted_plant(1.25, 1.05, seed=1, flower="#c4566e")
    olive_tree(1.6, 1.62, s=0.9, seed=3)


@building("house_2", 2)
def house_family():
    """Maison de famille : corps à étage avec balcon, aile basse, cour sous treille avec puits."""
    ground(3)
    walls(0.1, 0.1, 1.1, 1.0, 0.68, band="#a8382c")
    opening(("y", 1.0), 0.35, 0.06, 0.06, 0.29, kind="door")
    opening(("y", 1.0), 0.8, 0.04, 0.17, 0.28, color="#3c6e9a")
    opening(("y", 1.0), 0.45, 0.035, 0.44, 0.56, color="#3c6e9a")
    opening(("y", 1.0), 0.85, 0.035, 0.44, 0.56, color="#3c6e9a")
    opening(("x", 1.1), 0.45, 0.035, 0.44, 0.56, color="#3c6e9a")
    balcony(("y", 1.0), 0.3, 1.0, 0.4)
    prism_roof(0.1, 0.1, 1.1, 1.0, 0.68, 0.3, along="x", pediment=M("plaster"))
    walls(1.1, 0.15, 1.85, 0.8, 0.38, wall="plaster_warm", band="#a8382c")
    opening(("x", 1.85), 0.35, 0.055, 0.06, 0.28, kind="door")
    opening(("x", 1.85), 0.65, 0.035, 0.17, 0.27, color="#5b7a3a")
    opening(("y", 0.8), 1.5, 0.035, 0.17, 0.27, color="#5b7a3a")
    prism_roof(1.1, 0.15, 1.85, 0.8, 0.38, 0.2, along="y", pediment=M("plaster_warm"))
    paving(0.1, 1.05, 1.15, 1.85, scale=26)
    pergola(0.2, 1.15, 1.05, 1.75, h=0.32, seed=2)
    well(1.45, 1.35)
    rubble_wall(0.08, 1.9, 1.9, 1.9, h=0.13, seed=4)
    rubble_wall(1.9, 0.9, 1.9, 1.9, h=0.13, seed=5)
    pithos(0.3, 1.7, s=0.9)
    amphora(0.45, 1.75, s=0.8)
    for k, c in enumerate(("#c4566e", "#d9b13b", None)):
        potted_plant(1.25 + k * 0.12, 1.05, seed=k, flower=c)
    chicken(1.6, 1.7)
    cypress(1.75, 1.05, h=0.45, seed=8)


@building("house_3", 2)
def house_notable():
    """Maison de notable : ailes à étage autour d'une cour à portique, porche d'entrée à fronton."""
    tbox(0.02, 0.02, 0, 1.98, 1.98, 0.01, M("sol_cour", color="#cbbd9f", noise=0.15))
    walls(0.06, 0.06, 1.94, 0.68, 0.72, band="#a8382c")
    for x in (0.3, 0.75, 1.2, 1.65):
        opening(("y", 0.68), x, 0.035, 0.46, 0.6, color="#2f6f9f")
    balcony(("y", 0.68), 0.2, 1.0, 0.42)
    opening(("x", 1.94), 0.37, 0.035, 0.46, 0.6, color="#2f6f9f")
    opening(("x", 1.94), 0.37, 0.035, 0.17, 0.3, color="#2f6f9f")
    prism_roof(0.06, 0.06, 1.94, 0.68, 0.72, 0.3, along="x", pediment=M("plaster"))
    walls(0.06, 0.68, 0.66, 1.94, 0.5, band="#a8382c")
    for y in (1.0, 1.5):
        opening(("x", 0.66), y, 0.035, 0.24, 0.36, color="#2f6f9f")
    opening(("y", 1.94), 0.36, 0.035, 0.24, 0.36, color="#2f6f9f")
    prism_roof(0.06, 0.68, 0.66, 1.94, 0.5, 0.26, along="y", pediment=M("plaster"))
    # Cour pavée, portique, bassin, oliviers en pots.
    paving(0.66, 0.68, 1.94, 1.94, material="#d8ccb0", scale=24)
    colonnade(0.8, 0.82, 1.85, 0.82, 0.01, 0.38, 4, r=0.028)
    tbox(0.7, 0.68, 0.38, 1.92, 0.88, 0.41, M("marble"))
    tbox(0.7, 0.68, 0.41, 1.92, 0.88, 0.43, M("terracotta"))
    tbox(1.1, 1.15, 0.01, 1.45, 1.5, 0.06, M("marble"))
    water_surface(1.14, 1.19, 1.41, 1.46, 0.055)
    # Mur d'enceinte enduit à chaperon de tuiles, porche.
    tbox(0.66, 1.88, 0, 1.94, 1.94, 0.24, M("plaster", color="plaster", noise=0.08, scale=14))
    tbox(1.88, 0.88, 0, 1.94, 1.94, 0.24, M("plaster", color="plaster", noise=0.08, scale=14))
    tbox(0.64, 1.86, 0.24, 1.96, 1.96, 0.27, M("terracotta"))
    tbox(1.86, 0.88, 0.24, 1.96, 1.96, 0.27, M("terracotta"))
    opening(("x", 1.94), 1.4, 0.07, 0.0, 0.2, kind="door")
    tbox(1.92, 1.25, 0.0, 2.0, 1.55, 0.03, M("stone"))
    for y in (1.27, 1.53):
        cyl(1.97, y, 0.03, 0.3, 0.018, M("marble"), verts=10)
    tbox(1.9, 1.22, 0.3, 2.0, 1.58, 0.33, M("marble"))
    mesh([T(2.0, 1.22, 0.33), T(2.0, 1.4, 0.42), T(2.0, 1.58, 0.33)], [(0, 1, 2)], M("marble_shade", color="marble_shade"))
    potted_plant(0.8, 1.75, s=1.3, seed=3, flower="#c4566e")
    potted_plant(1.7, 1.0, s=1.3, seed=4)
    cypress(0.85, 1.05, h=0.42, seed=6)
    olive_tree(1.6, 1.65, s=0.9, seed=9)
    pithos(1.4, 1.75, s=0.8)


@building("house_4", 2)
def villa():
    """Villa : péristyle complet, ailes à étage, jardin avec fontaine et statue, propylée à fronton."""
    tbox(0.02, 0.02, 0, 1.98, 1.98, 0.012, M("sol_villa", color="#d8ccb0", kind="brick", scale=14))
    walls(0.04, 0.04, 1.96, 0.58, 0.8, band="#7a2a22")
    for x in (0.25, 0.6, 0.95, 1.3, 1.65):
        opening(("y", 0.58), x, 0.033, 0.52, 0.66, color="#2f6f9f")
    opening(("x", 1.96), 0.31, 0.033, 0.52, 0.66, color="#2f6f9f")
    balcony(("y", 0.58), 0.15, 1.85, 0.48, depth=0.1)
    prism_roof(0.04, 0.04, 1.96, 0.58, 0.8, 0.3, along="x", pediment=M("marble"))
    walls(0.04, 0.58, 0.56, 1.96, 0.62, band="#7a2a22")
    for y in (0.9, 1.3, 1.7):
        opening(("x", 0.56), y, 0.033, 0.38, 0.5, color="#2f6f9f")
    opening(("y", 1.96), 0.3, 0.033, 0.38, 0.5, color="#2f6f9f")
    prism_roof(0.04, 0.58, 0.56, 1.96, 0.62, 0.26, along="y", pediment=M("marble"))
    # Péristyle : quatre côtés de colonnes autour du jardin.
    x0, y0, x1, y1 = 0.68, 0.7, 1.86, 1.86
    colonnade(x0, y1, x1, y1, 0.012, 0.36, 5, r=0.026)
    colonnade(x1, y0, x1, y1, 0.012, 0.36, 5, r=0.026)
    colonnade(x0, y0, x1, y0, 0.012, 0.36, 5, r=0.026)
    colonnade(x0, y0, x0, y1, 0.012, 0.36, 5, r=0.026)
    for (a, b, c, d) in ((x0 - 0.05, y1 - 0.05, x1 + 0.05, y1 + 0.05), (x1 - 0.05, y0 - 0.05, x1 + 0.05, y1 + 0.05)):
        tbox(a, b, 0.36, c, d, 0.39, M("marble"))
        tbox(a, b, 0.39, c, d, 0.41, M("frise_villa", color="#2f6f9f"))
        prism_roof(a, b, c, d, 0.41, 0.07, along="x" if c - a > d - b else "y", pediment=M("marble"), overhang=0.02)
    tbox(x0 + 0.1, y0 + 0.1, 0.012, x1 - 0.1, y1 - 0.1, 0.03, M("jardin", color="#7d8f45", noise=0.2))
    tbox(1.12, 1.13, 0.03, 1.42, 1.43, 0.08, M("marble"))
    water_surface(1.15, 1.16, 1.39, 1.4, 0.075)
    statue(1.27, 1.28, 0.08, s=0.9)
    for (x, y) in ((0.88, 0.9), (1.65, 0.9), (0.88, 1.65), (1.65, 1.65)):
        bush(x, y, 0.03, 1.0, seed=int(x * 10 + y), color="leaf")
        potted_plant(x + 0.08, y, 0.03, seed=2, flower="#d9b13b")
    cypress(1.6, 1.15, 0.03, h=0.4, seed=3)
    cypress(0.9, 1.4, 0.03, h=0.38, seed=4)
