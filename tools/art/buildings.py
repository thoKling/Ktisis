"""Modèles des bâtiments. Chaque fonction construit la scène d'un sprite ; n = taille de l'emprise.

Coordonnées en tuiles : x vers le bas-droite de l'écran, y vers le bas-gauche. Les faces visibles
sont donc celles en x max (à droite) et y max (à gauche) : c'est là qu'on met portes et détails.
"""

import random

from kit import (PAL, M, T, amphora, awning, blob, box, bush, colonnade, column, crate, cyl, cypress,
                 entablature, fire, ground_pad, hip_roof, leafy_tree, mesh, olive_tree, paving, post,
                 prism_roof, sphere, statue, steps, tbox, water_surface, window)

BUILDINGS = {}


def building(name, size):
    def deco(fn):
        BUILDINGS[name] = (fn, size)
        return fn
    return deco


# --------------------------------------------------------------------------- habitat

def _house_walls(x0, y0, x1, y1, h, wall="plaster", base="stone"):
    tbox(x0, y0, 0, x1, y1, 0.05, M(base + "_soc", color=base, kind="brick", scale=30))
    tbox(x0 + 0.01, y0 + 0.01, 0.05, x1 - 0.01, y1 - 0.01, h, M(wall, color=wall, noise=0.06, scale=18))


def _door(x1, yc, h=0.2, w=0.06, side="x", frame="wood_dark"):
    if side == "x":
        tbox(x1 - 0.005, yc - w, 0.05, x1 + 0.012, yc + w, 0.05 + h, M(frame, color=frame, noise=0.05))
    else:
        tbox(yc - w, x1 - 0.005, 0.05, yc + w, x1 + 0.012, 0.05 + h, M(frame, color=frame, noise=0.05))


@building("house_0", 2)
def hut():
    """Hutte : murs de brique crue, toit de chaume, enclos de branchages."""
    ground_pad(2, "dirt")
    _house_walls(0.35, 0.3, 1.35, 1.2, 0.26, wall="mudbrick", base="stone_dark")
    _door(1.35, 0.8, h=0.17, w=0.05)
    window(("y", 1.2, 0.8), 0.04, 0.14, 0.2)
    th = M("thatch", color="thatch", noise=0.2, scale=30, bump=0.4)
    prism_roof(0.35, 0.3, 1.35, 1.2, 0.26, 0.3, along="x", material=th, overhang=0.09, tiles=False)
    # Enclos et petit potager.
    for i in range(7):
        post(1.55 + (i % 2) * 0.0, 0.2 + i * 0.22, 0, 0.12, r=0.01)
    tbox(0.4, 1.4, 0, 1.3, 1.85, 0.015, M("soil", color="soil", noise=0.2))
    for i in range(4):
        bush(0.5 + i * 0.22, 1.62, 0.015, 0.6, seed=i, color="olive")
    amphora(1.5, 1.3)
    crate(1.6, 1.6)


@building("house_1", 2)
def house_simple():
    ground_pad(2, "dirt")
    _house_walls(0.2, 0.25, 1.5, 1.35, 0.34)
    _door(1.5, 0.8)
    window(("y", 1.35, 0.55), 0.035, 0.2, 0.27)
    window(("y", 1.35, 1.15), 0.035, 0.2, 0.27)
    prism_roof(0.2, 0.25, 1.5, 1.35, 0.34, 0.26, along="x", pediment=M("plaster"))
    tbox(1.55, 0.3, 0, 1.85, 1.6, 0.012, M("soil", color="soil", noise=0.2))
    amphora(1.62, 1.45)
    amphora(1.72, 1.52, s=0.8)
    olive_tree(0.5, 1.7, s=0.8, seed=3)


@building("house_2", 2)
def house_family():
    ground_pad(2, "dirt")
    _house_walls(0.15, 0.15, 1.3, 1.1, 0.4)
    _house_walls(1.3, 0.4, 1.8, 1.1, 0.3, wall="plaster_warm")
    _door(1.8, 0.75)
    window(("y", 1.1, 0.4), 0.035, 0.25, 0.32)
    window(("y", 1.1, 0.95), 0.035, 0.25, 0.32)
    window(("x", 1.3, 0.28), 0.03, 0.28, 0.34)
    prism_roof(0.15, 0.15, 1.3, 1.1, 0.4, 0.28, along="x", pediment=M("plaster"))
    prism_roof(1.3, 0.4, 1.8, 1.1, 0.3, 0.16, along="y", pediment=M("plaster_warm"))
    # Cour avant avec muret, jarres et vigne.
    tbox(0.15, 1.85, 0, 1.85, 1.9, 0.12, M("plaster_warm"))
    tbox(1.85, 1.15, 0, 1.9, 1.9, 0.12, M("plaster_warm"))
    paving(0.2, 1.2, 1.8, 1.82, scale=24)
    amphora(0.4, 1.5)
    amphora(0.55, 1.6, s=0.85)
    for i in range(3):
        post(1.0 + i * 0.25, 1.75, 0, 0.3)
    tbox(0.95, 1.2, 0.3, 1.55, 1.8, 0.315, M("wood"))
    for i in range(5):
        blob(1.0 + i * 0.13, 1.5, 0.32, 0.07, M("leaf", color="leaf", noise=0.2), seed=i, sz=0.03)


@building("house_3", 2)
def house_notable():
    """Maison de notable : deux corps autour d'une cour, socle de pierre, portique d'entrée."""
    ground_pad(2, "stone")
    _house_walls(0.1, 0.1, 1.9, 0.75, 0.55)
    _house_walls(0.1, 0.75, 0.75, 1.9, 0.45)
    for x in (0.4, 0.95, 1.5):
        window(("y", 0.75, x), 0.035, 0.32, 0.44)
    window(("x", 0.75, 1.3), 0.035, 0.25, 0.36)
    window(("x", 0.75, 1.65), 0.035, 0.25, 0.36)
    prism_roof(0.1, 0.1, 1.9, 0.75, 0.55, 0.26, along="x", pediment=M("plaster"))
    prism_roof(0.1, 0.75, 0.75, 1.9, 0.45, 0.24, along="y", pediment=M("plaster"))
    # Cour pavée, bassin, mur de clôture et porche à colonnes.
    paving(0.75, 0.75, 1.9, 1.9, scale=22)
    tbox(1.85, 0.75, 0, 1.9, 1.9, 0.2, M("plaster"))
    tbox(0.75, 1.85, 0, 1.9, 1.9, 0.2, M("plaster"))
    colonnade(1.88, 1.15, 1.88, 1.5, 0.0, 0.32, 2, r=0.03)
    tbox(1.82, 1.08, 0.32, 1.95, 1.57, 0.36, M("marble"))
    tbox(1.15, 1.15, 0.015, 1.5, 1.5, 0.04, M("marble"))
    water_surface(1.18, 1.18, 1.47, 1.47, 0.035)
    cypress(0.95, 1.65, h=0.45, seed=2)
    bush(1.6, 0.95, 0.015, 0.8, seed=5)
    amphora(0.95, 0.95)


@building("house_4", 2)
def villa():
    """Villa : péristyle à colonnes, toits de tuiles, jardin, statue."""
    ground_pad(2, "stone")
    paving(0.05, 0.05, 1.95, 1.95, scale=20)
    _house_walls(0.08, 0.08, 1.92, 0.6, 0.6)
    _house_walls(0.08, 0.6, 0.6, 1.92, 0.6)
    _house_walls(1.4, 0.6, 1.92, 1.92, 0.42, wall="plaster_warm")
    for x in (0.35, 0.8, 1.25, 1.65):
        window(("y", 0.6, x), 0.03, 0.36, 0.48)
    prism_roof(0.08, 0.08, 1.92, 0.6, 0.6, 0.24, along="x", pediment=M("marble"))
    prism_roof(0.08, 0.6, 0.6, 1.92, 0.6, 0.24, along="y", pediment=M("marble"))
    prism_roof(1.4, 0.6, 1.92, 1.92, 0.42, 0.2, along="y", pediment=M("plaster_warm"))
    # Péristyle
    colonnade(0.7, 1.82, 1.32, 1.82, 0.0, 0.34, 4, r=0.028)
    colonnade(0.7, 0.7, 0.7, 1.82, 0.0, 0.34, 4, r=0.028)
    tbox(0.62, 1.76, 0.34, 1.38, 1.9, 0.38, M("marble"))
    tbox(0.62, 0.62, 0.34, 0.76, 1.9, 0.38, M("marble"))
    tbox(0.8, 0.7, 0.012, 1.35, 1.72, 0.03, M("grass", color="grass", noise=0.2))
    bush(0.95, 0.9, 0.03, 0.9, seed=1)
    bush(1.2, 1.55, 0.03, 0.9, seed=2, color="olive")
    statue(1.08, 1.2, 0.03, s=0.7)
    window(("x", 1.92, 1.0), 0.06, 0.05, 0.3, material="wood_dark")


# --------------------------------------------------------------------------- services et religion

@building("fountain", 1)
def fountain():
    paving(0.05, 0.05, 0.95, 0.95, scale=20)
    m = M("marble")
    tbox(0.15, 0.15, 0.015, 0.85, 0.85, 0.1, m, bevel=0.01)
    water_surface(0.2, 0.2, 0.8, 0.8, 0.09)
    # Fontaine à tête de lion : stèle avec petit fronton au fond.
    tbox(0.18, 0.2, 0.1, 0.82, 0.3, 0.42, M("marble"))
    mesh([T(0.18, 0.25, 0.42), T(0.5, 0.25, 0.52), T(0.82, 0.25, 0.42)], [(0, 1, 2)], M("marble_shade", color="marble_shade"))
    tbox(0.16, 0.18, 0.42, 0.84, 0.32, 0.44, M("marble"))
    sphere(0.5, 0.33, 0.3, 0.03, M("gold", color="gold", rough=0.4))
    tbox(0.49, 0.33, 0.1, 0.51, 0.35, 0.29, M("eau_jet", color="aegean_light", emit=0.3))
    amphora(0.82, 0.82, 0.1, s=0.9)


@building("altar_demeter", 2)
def altar_demeter():
    _altar("wheat", "ochre")


@building("altar_athena", 2)
def altar_athena():
    _altar("olive", "aegean")


@building("altar_poseidon", 2)
def altar_poseidon():
    _altar("aegean_light", "aegean")


@building("altar_hera", 2)
def altar_hera():
    _altar("cloth_red", "cloth_red")


def _altar(accent, frieze):
    """Petit sanctuaire : naïskos à colonnes avec fronton, autel du feu devant."""
    paving(0.05, 0.05, 1.95, 1.95, material="marble_shade", scale=16)
    z = steps(0.15, 0.1, 1.3, 1.4, 0.015, n=3)
    m = M("marble")
    tbox(0.3, 0.25, z, 1.15, 0.95, z + 0.5, M("marble_mur", color="marble", kind="brick", scale=26))
    colonnade(0.3, 1.25, 1.15, 1.25, z, 0.5, 4, r=0.035)
    colonnade(1.15, 0.25, 1.15, 1.25, z, 0.5, 5, r=0.035)
    window(("y", 0.95, 0.72), 0.12, z, z + 0.4, material="black")
    entablature(0.25, 0.2, 1.2, 1.3, z + 0.5, h=0.12, frieze=frieze)
    prism_roof(0.25, 0.2, 1.2, 1.3, z + 0.62, 0.22, along="y", pediment=M("marble_shade", color="marble_shade"), overhang=0.03)
    sphere(0.725, 1.3, z + 0.72, 0.03, M("gold", color="gold", rough=0.4))
    # Autel du feu et offrandes.
    tbox(1.45, 1.35, 0.015, 1.75, 1.65, 0.2, m, bevel=0.01)
    tbox(1.43, 1.33, 0.2, 1.77, 1.67, 0.23, M(frieze, color=frieze))
    fire(1.6, 1.5, 0.23, s=1.4)
    amphora(1.45, 1.8, 0.015, s=1.0)
    for i in range(3):
        bush(0.3 + i * 0.35, 1.75, 0.015, 0.7, seed=i, color=accent if accent in PAL else "leaf")
    cypress(1.75, 0.3, h=0.6, seed=4)
    cypress(1.8, 0.75, h=0.5, seed=5)


@building("agora", 3)
def agora():
    """Agora : stoa à colonnade au fond, étals sous auvents rayés sur la place."""
    paving(0.03, 0.03, 2.97, 2.97, scale=12)
    z = steps(0.1, 0.1, 2.9, 0.9, 0.015, n=2)
    tbox(0.15, 0.15, z, 2.85, 0.45, z + 0.55, M("plaster", color="plaster", noise=0.05))
    for x in (0.5, 1.1, 1.7, 2.3):
        window(("y", 0.45, x), 0.08, z, z + 0.35, material="wood_dark")
    colonnade(0.2, 0.82, 2.8, 0.82, z, 0.55, 10, r=0.035)
    tbox(0.15, 0.45, z + 0.53, 2.85, 0.86, z + 0.55, M("wood"))
    entablature(0.12, 0.12, 2.88, 0.88, z + 0.55, h=0.1, frieze="aegean")
    prism_roof(0.12, 0.12, 2.88, 0.88, z + 0.65, 0.2, along="x", pediment=M("marble_shade", color="marble_shade"), overhang=0.03)
    # Étals.
    stalls = [(0.4, 1.3, ("cloth_red", "cloth_white")), (1.3, 1.3, ("cloth_blue", "cloth_white")),
              (2.2, 1.3, ("ochre", "cloth_white")), (0.4, 2.2, ("cloth_blue", "cloth_white")),
              (2.2, 2.2, ("cloth_red", "cloth_white"))]
    rnd = random.Random(7)
    for (x, y, cols) in stalls:
        tbox(x, y + 0.15, 0.015, x + 0.55, y + 0.35, 0.14, M("wood"))
        for px, py in ((x, y), (x + 0.55, y), (x, y + 0.4), (x + 0.55, y + 0.4)):
            post(px, py, 0.015, 0.32 if py == y else 0.26)
        awning(x - 0.04, y - 0.04, x + 0.59, y + 0.46, 0.33, 0.26, along="x", colors=cols, stripes=5)
        for k in range(3):
            kind = rnd.choice(["amph", "crate", "fruit"])
            px = x + 0.1 + k * 0.17
            if kind == "amph":
                amphora(px, y + 0.25, 0.14, s=0.6)
            elif kind == "crate":
                crate(px, y + 0.25, 0.14, s=0.06)
            else:
                sphere(px, y + 0.25, 0.16, 0.03, M(rnd.choice(["ochre", "cloth_red", "olive"])))
    statue(1.55, 2.4, 0.015, s=1.0)
    cypress(2.85, 2.85, h=0.5, seed=1)
    olive_tree(0.25, 2.8, s=1.0, seed=8)


@building("granary", 3)
def granary():
    """Grenier : grand bâtiment de pierre à toit de tuiles, silos ronds, sacs et jarres."""
    ground_pad(3, "dirt")
    tbox(0.15, 0.15, 0, 2.2, 1.5, 0.12, M("stone_soc", color="stone", kind="brick", scale=22))
    tbox(0.17, 0.17, 0.12, 2.18, 1.48, 0.62, M("plaster_warm", color="plaster_warm", noise=0.06))
    for x in (0.5, 1.1, 1.7):
        window(("y", 1.48, x), 0.04, 0.45, 0.55)
    window(("x", 2.18, 0.8), 0.12, 0.12, 0.45, material="wood_dark")
    prism_roof(0.15, 0.15, 2.2, 1.5, 0.62, 0.36, along="x", pediment=M("plaster_warm"))
    # Silos ronds en brique crue à coupole.
    for (x, y) in ((2.55, 0.5), (2.55, 1.15)):
        cyl(x, y, 0, 0.45, 0.28, M("mudbrick", color="mudbrick", noise=0.1), verts=20)
        sphere(x, y, 0.45, 0.28, M("mudbrick", color="mudbrick", noise=0.1), sz=0.18, seg=20, rings=8)
    # Cour de déchargement.
    for i in range(5):
        sphere(0.5 + i * 0.16, 1.85, 0.05, 0.06, M("sac", color="#d8c39a", noise=0.1), sz=0.05)
    for i in range(4):
        amphora(1.6 + (i % 2) * 0.12, 1.8 + (i // 2) * 0.12)
    crate(2.3, 2.0, s=0.12)
    crate(2.42, 2.05, s=0.1)
    tbox(0.4, 2.3, 0, 1.0, 2.6, 0.02, M("wheat_tas", color="wheat", noise=0.2))
    blob(0.7, 2.45, 0.02, 0.2, M("wheat_tas", color="wheat", noise=0.2), sz=0.1, seed=2)
    # Charrette.
    tbox(1.7, 2.3, 0.1, 2.2, 2.6, 0.16, M("wood"))
    for x in (1.8, 2.1):
        wheel(x, 2.62, 0.09)


@building("farm", 3)
def farm():
    """Ferme de blé : champs en sillons dorés, petite ferme, meule et épouvantail."""
    rnd = random.Random(4)
    tbox(0.02, 0.02, 0, 2.98, 2.98, 0.01, M("soil", color="soil", noise=0.2, scale=10))
    wheat = M("wheat", color="wheat", noise=0.15, scale=30, bump=0.5)
    green = M("ble_vert", color="#b5b65a", noise=0.15, scale=30, bump=0.5)
    # Sillons orientés selon x, deux parcelles.
    for i in range(14):
        y = 0.12 + i * 0.13
        if y > 1.95:
            break
        tbox(0.1, y, 0.01, 1.85, y + 0.09, 0.075 + rnd.uniform(0, 0.02), wheat)
    for i in range(8):
        y = 2.0 + i * 0.12
        if y > 2.85:
            break
        tbox(0.1, y, 0.01, 1.4, y + 0.08, 0.05, green)
    # Ferme.
    tbox(2.05, 0.2, 0, 2.85, 0.9, 0.04, M("stone"))
    tbox(2.08, 0.23, 0.04, 2.82, 0.87, 0.36, M("mudbrick", color="mudbrick", noise=0.08))
    window(("y", 0.87, 2.45), 0.05, 0.05, 0.25, material="wood_dark")
    prism_roof(2.08, 0.23, 2.82, 0.87, 0.36, 0.22, along="x", material=M("thatch", color="thatch", noise=0.2, bump=0.4), tiles=False)
    # Meules et aire de battage.
    for (x, y) in ((2.3, 1.4), (2.65, 1.5)):
        cyl(x, y, 0.01, 0.14, 0.13, M("wheat_tas", color="wheat", noise=0.2), verts=14)
        bpy_cone(x, y, 0.14, 0.13, 0.14)
    cyl(2.2, 2.3, 0.01, 0.025, 0.4, M("stone_aire", color="stone", noise=0.1), verts=24)
    post(1.6, 2.4, 0, 0.3, r=0.012)
    tbox(1.5, 2.395, 0.22, 1.7, 2.405, 0.235, M("wood"))
    sphere(1.6, 2.4, 0.32, 0.03, M("thatch", color="thatch"))
    olive_tree(2.75, 2.75, s=1.1, seed=2)


def wheel(tx, ty, r):
    import bpy
    import math
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r, depth=0.025, location=(tx, -ty, r))
    o = bpy.context.object
    o.rotation_euler = (math.radians(90), 0, 0)
    o.data.materials.append(M("wood_dark"))


def bpy_cone(tx, ty, z, r, h):
    import bpy
    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=r, radius2=0.0, depth=h, location=(tx, -ty, z + h / 2))
    o = bpy.context.object
    o.data.materials.append(M("wheat_tas", color="wheat", noise=0.2))


# --------------------------------------------------------------------------- décor du terrain (assets/props)

PROPS = {}


def prop(name):
    def deco(fn):
        PROPS[name] = (fn, 1)
        return fn
    return deco


def _forest(seed):
    rnd = random.Random(seed)
    spots = [(0.3, 0.3), (0.7, 0.3), (0.3, 0.7), (0.7, 0.7), (0.5, 0.5)]
    rnd.shuffle(spots)
    for k, (x, y) in enumerate(spots[:4]):
        x += rnd.uniform(-0.08, 0.08)
        y += rnd.uniform(-0.08, 0.08)
        kind = rnd.random()
        if kind < 0.3:
            cypress(x, y, h=rnd.uniform(0.5, 0.75), seed=seed * 10 + k)
        elif kind < 0.65:
            pine(x, y, s=rnd.uniform(0.8, 1.1), seed=seed * 10 + k)
        else:
            leafy_tree(x, y, s=rnd.uniform(0.8, 1.05), seed=seed * 10 + k, color=rnd.choice(["leaf", "olive_dark"]))
    for k in range(2):
        bush(rnd.uniform(0.15, 0.85), rnd.uniform(0.15, 0.85), 0, 0.8, seed=seed + k, color="olive_dark")


def pine(tx, ty, s=1.0, seed=0):
    """Pin parasol : tronc fin, houppier plat."""
    rnd = random.Random(seed)
    cyl(tx, ty, 0, 0.32 * s, 0.022 * s, M("wood_dark"), verts=6, r_top=0.015 * s)
    leaf = M("pin", color="#4f6a33", noise=0.2, scale=22)
    for k in range(3):
        blob(tx + rnd.uniform(-0.06, 0.06) * s, ty + rnd.uniform(-0.06, 0.06) * s, (0.36 + k * 0.03) * s,
             0.15 * s, leaf, seed=seed * 3 + k, sz=0.06 * s)


def _rocks(seed):
    rnd = random.Random(seed)
    stone = M("rocher", color="#b3aa98", noise=0.12, scale=12, bump=0.6)
    dark = M("rocher_sombre", color="#958b78", noise=0.12, scale=12, bump=0.6)
    for k in range(rnd.randint(3, 5)):
        x, y = rnd.uniform(0.2, 0.8), rnd.uniform(0.2, 0.8)
        r = rnd.uniform(0.1, 0.22)
        blob(x, y, r * 0.25, r, rnd.choice([stone, dark]), seed=seed * 5 + k, sz=r * rnd.uniform(0.6, 1.1), lumps=0.3)
    if rnd.random() < 0.6:
        bush(rnd.uniform(0.2, 0.8), rnd.uniform(0.6, 0.9), 0, 0.7, seed=seed, color="olive")


for _i in range(4):
    PROPS["forest_%d" % _i] = ((lambda i: lambda: _forest(i))(_i), 1)
for _i in range(3):
    PROPS["rock_%d" % _i] = ((lambda i: lambda: _rocks(i + 11))(_i), 1)


# --------------------------------------------------------------------------- services, beauté

@building("tax_office", 2)
def tax_office():
    """Bureau du percepteur : bâtiment de pierre à portique, coffres et balance devant."""
    paving(0.05, 0.05, 1.95, 1.95, scale=18)
    z = steps(0.15, 0.15, 1.6, 1.25, 0.015, n=2)
    tbox(0.2, 0.2, z, 1.55, 0.85, z + 0.5, M("marble_mur", color="marble", kind="brick", scale=26))
    window(("y", 0.85, 0.85), 0.09, z, z + 0.32, material="wood_dark")
    window(("x", 1.55, 0.5), 0.04, z + 0.2, z + 0.34)
    colonnade(0.25, 1.18, 1.5, 1.18, z, 0.42, 4, r=0.03)
    entablature(0.18, 0.85, 1.57, 1.22, z + 0.42, h=0.08, frieze="ochre")
    tbox(0.18, 0.18, z + 0.5, 1.57, 0.88, z + 0.53, M("marble"))
    prism_roof(0.18, 0.18, 1.57, 0.88, z + 0.53, 0.22, along="x", pediment=M("marble_shade", color="marble_shade"), overhang=0.03)
    tbox(0.18, 0.85, z + 0.5, 1.57, 1.22, z + 0.52, M("terracotta"))
    for (x, y) in ((1.7, 1.45), (1.45, 1.7)):
        tbox(x - 0.09, y - 0.06, 0.015, x + 0.09, y + 0.06, 0.12, M("wood"), bevel=0.005)
        tbox(x - 0.09, y - 0.06, 0.12, x + 0.09, y + 0.06, 0.14, M("gold", color="gold", rough=0.4))
    for i in range(4):
        cyl(1.1 + i * 0.05, 1.55, 0.015, 0.03 + i * 0.008, 0.025, M("gold", color="gold", rough=0.35), verts=10)
    amphora(0.3, 1.6, 0.015)
    cypress(0.25, 1.8, h=0.4, seed=7)


@building("guard_post", 1)
def guard_post():
    """Poste de vigie : petite tour de pierre, bouclier rond et lance à l'entrée."""
    paving(0.05, 0.05, 0.95, 0.95, scale=20)
    tbox(0.18, 0.18, 0.015, 0.72, 0.72, 0.6, M("stone_tour", color="stone", kind="brick", scale=26))
    tbox(0.15, 0.15, 0.6, 0.75, 0.75, 0.64, M("stone"))
    for (x, y) in ((0.15, 0.15), (0.6, 0.15), (0.15, 0.6), (0.6, 0.6), (0.375, 0.15), (0.15, 0.375), (0.6, 0.375), (0.375, 0.6)):
        tbox(x, y, 0.64, x + 0.15, y + 0.15, 0.71, M("stone"))
    window(("y", 0.72, 0.45), 0.07, 0.015, 0.3, material="wood_dark")
    window(("x", 0.72, 0.45), 0.025, 0.38, 0.48)
    import bpy
    import math
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.1, depth=0.02, location=(0.82, -0.6, 0.18))
    o = bpy.context.object
    o.rotation_euler = (0, math.radians(90), 0)
    o.data.materials.append(M("bouclier", color="cloth_red", noise=0.05))
    sphere(0.835, 0.6, 0.18, 0.025, M("gold", color="gold", rough=0.4))
    cyl(0.85, 0.4, 0.015, 0.55, 0.008, M("wood"), verts=6)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.016, radius2=0.0, depth=0.06, location=(0.85, -0.4, 0.58))
    bpy.context.object.data.materials.append(M("bronze", color="#a8783c", rough=0.4))
    # Torche sur le toit.
    fire(0.45, 0.45, 0.64, s=0.8)


@building("garden", 1)
def garden():
    """Jardin : buis taillés, allée, cyprès et banc."""
    tbox(0.03, 0.03, 0, 0.97, 0.97, 0.012, M("grass", color="grass", noise=0.2, scale=14))
    tbox(0.42, 0.03, 0.012, 0.58, 0.97, 0.018, M("allee", color="#d8c8a4", noise=0.1))
    tbox(0.03, 0.42, 0.012, 0.97, 0.58, 0.018, M("allee", color="#d8c8a4", noise=0.1))
    for (x, y) in ((0.2, 0.2), (0.8, 0.2), (0.2, 0.8), (0.8, 0.8)):
        bush(x, y, 0.012, 1.4, seed=int(x * 10 + y), color="leaf")
        for k in range(3):
            sphere(x + 0.08 * (k - 1), y + 0.1, 0.07, 0.012, M("fleur", color=["cloth_red", "cloth_white", "ochre"][k], noise=0.0))
    cypress(0.2, 0.2, h=0.55, seed=3)
    cypress(0.8, 0.8, h=0.5, seed=4)
    olive_tree(0.8, 0.2, s=1.1, seed=5)
    tbox(0.45, 0.45, 0.018, 0.55, 0.55, 0.08, M("marble"), bevel=0.006)
    amphora(0.5, 0.5, 0.08, s=0.9)


@building("plaza", 2)
def plaza():
    """Place pavée : dallage de marbre, platanes, bancs et petite fontaine centrale."""
    paving(0.03, 0.03, 1.97, 1.97, material="stone", scale=12)
    tbox(0.12, 0.12, 0.015, 1.88, 1.88, 0.02, M("dalle_place", color="#d6c9ae", kind="brick", scale=10))
    tbox(0.8, 0.8, 0.02, 1.2, 1.2, 0.1, M("marble"), bevel=0.01)
    water_surface(0.84, 0.84, 1.16, 1.16, 0.09)
    column(1.0, 1.0, 0.09, 0.18, r=0.03)
    sphere(1.0, 1.0, 0.3, 0.035, M("bronze", color="#a8783c", rough=0.4))
    for (x, y) in ((0.35, 0.35), (1.65, 0.35), (0.35, 1.65), (1.65, 1.65)):
        tbox(x - 0.1, y - 0.1, 0.02, x + 0.1, y + 0.1, 0.06, M("marble"))
        leafy_tree(x, y, 0.06, s=1.1, seed=int(x * 7 + y * 3))
    for (x0, y0, x1, y1) in ((0.7, 0.35, 1.3, 0.42), (0.7, 1.58, 1.3, 1.65), (0.35, 0.7, 0.42, 1.3), (1.58, 0.7, 1.65, 1.3)):
        tbox(x0, y0, 0.02, x1, y1, 0.07, M("marble"), bevel=0.005)


@building("statue", 1)
def statue_b():
    paving(0.08, 0.08, 0.92, 0.92, material="marble_shade", scale=14)
    steps(0.2, 0.2, 0.8, 0.8, 0.015, n=2, rise=0.04)
    statue(0.5, 0.5, 0.095, s=2.2, pose=0)
    for (x, y) in ((0.15, 0.85), (0.85, 0.15)):
        bush(x, y, 0.015, 0.9, seed=int(x * 10))


# --------------------------------------------------------------------------- marcheurs (assets/walkers)

WALKERS = {}

SKIN = "#c98e62"


def person(tx, ty, robe, s=1.0, hair="#3a2a1e", long_robe=True, head=None):
    """Silhouette stylisée tournée vers la caméra (bas de l'écran)."""
    robe_m = M("robe_" + robe, color=robe, noise=0.05)
    skin = M("peau", color=SKIN, noise=0.0)
    if long_robe:
        cyl(tx, ty, 0, 0.26 * s, 0.07 * s, robe_m, verts=12, r_top=0.045 * s)
    else:
        for d in (-0.025, 0.025):
            cyl(tx + d * s, ty - d * s, 0, 0.12 * s, 0.015 * s, skin, verts=6)
        cyl(tx, ty, 0.1 * s, 0.26 * s, 0.055 * s, robe_m, verts=12, r_top=0.045 * s)
    cyl(tx, ty, 0.24 * s, 0.33 * s, 0.045 * s, robe_m, verts=12, r_top=0.04 * s)
    # Bras le long du corps.
    for d in (-0.05, 0.05):
        cyl(tx + d * s, ty - d * s, 0.17 * s, 0.32 * s, 0.014 * s, skin, verts=6)
    sphere(tx, ty, 0.375 * s, 0.04 * s, skin)
    sphere(tx - 0.008 * s, ty - 0.008 * s, 0.39 * s, 0.038 * s, M("cheveux_" + hair, color=hair, noise=0.0), sz=0.03 * s)
    return 0.42 * s


def walker(name):
    def deco(fn):
        WALKERS[name] = (fn, 0.5)
        return fn
    return deco


@walker("water")
def w_water():
    top = person(0.5, 0.5, "#4f8fc0")
    amphora(0.5, 0.5, top - 0.01, s=1.0, material="terracotta")


@walker("market")
def w_market():
    person(0.5, 0.5, "#c9783a", hair="#5a3a22")
    cyl(0.56, 0.44, 0.15, 0.22, 0.05, M("osier", color="#b8925a", noise=0.1), verts=10)
    for k in range(3):
        sphere(0.55 + k * 0.015, 0.44, 0.23, 0.018, M(["cloth_red", "ochre", "olive"][k]))


@walker("priest")
def w_priest():
    person(0.5, 0.5, "#f2ede0", hair="#d8d2c4")
    cyl(0.57, 0.43, 0.0, 0.42, 0.008, M("gold", color="gold", rough=0.4), verts=6)
    sphere(0.57, 0.43, 0.43, 0.018, M("gold", color="gold", rough=0.4))


@walker("sanctuary")
def w_sanctuary():
    person(0.5, 0.5, "#9a6fc0", hair="#2a1e14")
    fire(0.57, 0.43, 0.3, s=0.7)
    cyl(0.57, 0.43, 0.15, 0.3, 0.008, M("wood"), verts=6)


@walker("tax")
def w_tax():
    person(0.5, 0.5, "#d8b04a", long_robe=False, hair="#2a1e14")
    sphere(0.56, 0.44, 0.17, 0.035, M("bourse", color="#7a4a2a", noise=0.05))
    cyl(0.44, 0.56, 0.2, 0.3, 0.03, M("tablette", color="#e8dcc0"), verts=4)


@walker("guard")
def w_guard():
    top = person(0.5, 0.5, "#a8382c", long_robe=False)
    sphere(0.5, 0.5, top - 0.03, 0.048, M("bronze", color="#b08440", rough=0.35), sz=0.05)
    tbox(0.49, 0.49, top + 0.01, 0.51, 0.51, top + 0.07, M("cimier", color="cloth_red"))
    cyl(0.58, 0.42, 0.0, 0.55, 0.008, M("wood"), verts=6)
    import bpy
    import math
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.09, depth=0.015, location=(0.44, -0.56, 0.2))
    o = bpy.context.object
    o.rotation_euler = (math.radians(90), 0, math.radians(45))
    o.data.materials.append(M("bronze", color="#b08440", rough=0.35))


@walker("cart")
def w_cart():
    """Charrette à bras chargée d'amphores et de sacs, tirée par un âne."""
    tbox(0.38, 0.4, 0.07, 0.62, 0.62, 0.12, M("wood"))
    for (x0, y0, x1, y1) in ((0.38, 0.4, 0.62, 0.42), (0.38, 0.6, 0.62, 0.62), (0.6, 0.4, 0.62, 0.62), (0.38, 0.4, 0.4, 0.62)):
        tbox(x0, y0, 0.12, x1, y1, 0.17, M("wood"))
    import bpy
    import math
    for y in (0.38, 0.64):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.07, depth=0.02, location=(0.5, -y, 0.07))
        o = bpy.context.object
        o.rotation_euler = (math.radians(90), 0, 0)
        o.data.materials.append(M("wood_dark"))
    amphora(0.46, 0.47, 0.12, s=0.9)
    amphora(0.55, 0.55, 0.12, s=0.9)
    sphere(0.48, 0.56, 0.16, 0.04, M("sac", color="#d8c39a", noise=0.1), sz=0.035)
    # Âne.
    donkey = M("ane", color="#8a7d6e", noise=0.05)
    sphere(0.82, 0.51, 0.16, 0.09, donkey, sz=0.05)
    for (dx, dy) in ((-0.05, -0.025), (-0.05, 0.025), (0.05, -0.025), (0.05, 0.025)):
        cyl(0.82 + dx, 0.51 + dy, 0, 0.14, 0.01, donkey, verts=6)
    sphere(0.93, 0.51, 0.22, 0.035, donkey, sz=0.03)
    tbox(0.62, 0.5, 0.11, 0.76, 0.52, 0.12, M("wood"))


@walker("immigrant")
def w_immigrant():
    """Petite famille de colons avec baluchons."""
    person(0.42, 0.55, "#8a7a62", s=1.0)
    sphere(0.36, 0.6, 0.3, 0.05, M("baluchon", color="#c9b48a", noise=0.1))
    person(0.6, 0.42, "#6e7f5a", s=0.95, hair="#5a3a22")
    person(0.58, 0.6, "#a0705a", s=0.6)
