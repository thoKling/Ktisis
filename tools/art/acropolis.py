"""L'Acropole d'Athènes : Propylées, Parthénon, temple de Poséidon et les présents des deux dieux.

Tout se pose sur la colline sacrée : le sol de l'emprise reprend son calcaire clair.
"""

import random

from buildings import BUILDINGS, building, _col, _scaffold
from kit import (M, bush, column, cyl, cypress, entablature, fire, mesh, olive_tree, paving, pebbles, post,
                 prism_roof, rubble_wall, sphere, statue, steps, tbox, tufts, water_surface, T)

ROCK = "#d6c7a2"


def _rock_pad(n, seed=0):
    """Sol de calcaire de la colline, avec quelques touffes d'herbe sèche."""
    tbox(0.02, 0.02, 0, n - 0.02, n - 0.02, 0.012, M("calcaire", color=ROCK, noise=0.25, scale=7, bump=0.4))
    tufts(0.05, n - 0.2, n - 0.05, n - 0.04, int(3 * n), seed, color="#9a9a58")
    tufts(n - 0.2, 0.05, n - 0.04, n - 0.05, int(3 * n), seed + 1, color="#9a9a58")
    pebbles(0.1, 0.1, n - 0.1, n - 0.1, int(5 * n), seed)


def _blocks(x, y, n, seed=0):
    """Tas de blocs de marbre en attente sur le chantier."""
    rnd = random.Random(seed)
    for k in range(n):
        dx, dy = (k % 3) * 0.24, (k // 3) * 0.26
        h = 0.12 + rnd.uniform(0, 0.05)
        tbox(x + dx, y + dy, 0.012, x + dx + 0.2, y + dy + 0.22, 0.012 + h * (1 + (k % 2)), M("marble"), bevel=0.01)


def _crane(x, y, h):
    """Chèvre de levage : trois perches de bois et un bloc suspendu."""
    wood = M("wood")
    for d in ((-0.12, 0.08), (0.12, 0.08), (0, -0.14)):
        post(x + d[0], y + d[1], 0.012, h, r=0.014)
    tbox(x - 0.03, y - 0.03, h - 0.03, x + 0.03, y + 0.03, h + 0.02, wood)
    cyl(x, y, h * 0.45, h - 0.02, 0.003, M("corde", color="#cdb88a"), verts=4)
    tbox(x - 0.08, y - 0.07, h * 0.35, x + 0.08, y + 0.07, h * 0.45, M("marble"), bevel=0.008)


# --------------------------------------------------------------------------- Propylées (3x3)

def _propylaea(stage):
    """Porte monumentale : portique central à six colonnes sur la face avant, deux ailes basses.

    stage 0 : fondations et blocs ; 1 : colonnes à mi-hauteur ; 2 : achevé.
    """
    _rock_pad(3, seed=5)
    z = steps(0.25, 0.3, 2.9, 2.75, 0.012, n=4, rise=0.045, inset=0.06)
    if stage == 0:
        _blocks(0.4, 0.4, 6, seed=1)
        _crane(2.3, 2.2, 0.75)
        return
    frac = 0.5 if stage == 1 else 1.0
    h = 0.8
    wall = M("marble_mur", color="marble", kind="brick", scale=20)
    # Corps central : le passage, entre deux murs de refend.
    tbox(0.7, 0.75, z, 2.3, 2.25, z + h * frac, wall)
    # Portique sur la face visible en y max (six colonnes doriques), et sur la face x max.
    for i in range(6):
        t = i / 5
        _col(0.6 + 1.8 * t, 2.45, z, h * frac, frac)
    for i in range(4):
        t = i / 3
        _col(2.55, 0.85 + 1.4 * t, z, h * frac, frac)
    # Ailes : la pinacothèque à gauche, le petit temple d'Athéna Niké à droite.
    tbox(0.3, 0.3, z, 0.95, 0.95, z + 0.5 * frac, wall)
    tbox(2.2, 0.3, z, 2.8, 0.75, z + 0.45 * frac, wall)
    if stage == 1:
        _crane(1.5, 2.6, 1.1)
        _blocks(0.35, 2.0, 3, seed=2)
        return
    entablature(0.45, 0.75, 2.7, 2.6, z + h, h=0.18, frieze="aegean")
    prism_roof(0.5, 0.8, 2.65, 2.55, z + h + 0.18, 0.3, along="x", material="marble_shade",
               pediment=M("marble_shade", color="marble_shade"), overhang=0.04, tiles=False)
    prism_roof(0.25, 0.25, 1.0, 1.0, z + 0.5, 0.16, along="x")
    prism_roof(2.15, 0.25, 2.85, 0.8, z + 0.45, 0.14, along="y")
    # Le passage central, sombre, et les grandes portes de bronze.
    tbox(1.3, 2.3, z, 1.7, 2.32, z + 0.6, M("black"))
    for (x, y) in ((0.15, 2.85), (2.85, 2.85)):
        statue(x, y, 0.012, s=1.4)


for _s in range(2):
    BUILDINGS["propylaea_s%d" % _s] = ((lambda s: lambda: _propylaea(s))(_s), 3)
BUILDINGS["propylaea"] = (lambda: _propylaea(2), 3)


# --------------------------------------------------------------------------- Grands temples (4x4)

def _great_temple(stage, god):
    """Grand temple périptère de l'Acropole : huit colonnes en façade, frise peinte, statue colossale du dieu.

    stage 0-2 : chantier ; 3 : achevé. Athéna : Parthénon dorique, Athéna Promachos dorée et son olivier.
    Poséidon : frise bleue, trident de bronze, bassin d'eau de mer et chevaux.
    """
    frieze = "cloth_red" if god == "athena" else "aegean"
    _rock_pad(4, seed=7 if god == "athena" else 9)
    x0, y0, x1, y1 = 0.25, 0.2, 3.0, 3.75
    z = steps(x0 - 0.12, y0 - 0.12, x1 + 0.12, y1 + 0.12, 0.012, n=3, rise=0.06, inset=0.05)
    hcol = 1.0
    if stage == 0:
        _blocks(3.1, 0.3, 9, seed=3)
        _crane(1.6, 2.0, 0.9)
        tbox(x0 + 0.1, y0 + 0.1, z, x1 - 0.1, y1 - 0.1, z + 0.05, M("marble"))
        return
    n_front, n_side = 8, 12
    frac = 0.5 if stage == 1 else 1.0
    h = hcol * frac
    cella = M("marble_mur", color="marble", kind="brick", scale=20)
    tbox(x0 + 0.42, y0 + 0.5, z, x1 - 0.42, y1 - 0.5, z + h, cella)
    for i in range(n_front):
        t = i / (n_front - 1)
        for yy in (y0 + 0.1, y1 - 0.1):
            _col(x0 + 0.1 + (x1 - x0 - 0.2) * t, yy, z, h, frac)
    for i in range(1, n_side - 1):
        t = i / (n_side - 1)
        for xx in (x0 + 0.1, x1 - 0.1):
            _col(xx, y0 + 0.1 + (y1 - y0 - 0.2) * t, z, h, frac)
    if stage == 1:
        _crane(x1 + 0.4, y1 - 0.5, 1.3)
        _blocks(3.2, 0.4, 6, seed=4)
        return
    entablature(x0, y0, x1, y1, z + hcol, h=0.22, frieze=frieze)
    if stage == 2:
        _scaffold(x1 + 0.2, y1 + 0.05, 1.5)
        for i in range(10):
            y = y0 + (y1 - y0) * i / 9
            tbox(x0, y - 0.02, z + hcol + 0.22, x1, y + 0.02, z + hcol + 0.26, M("wood"))
        return
    if god == "athena":
        prism_roof(x0, y0, x1, y1, z + hcol + 0.22, 0.46, along="y", pediment=M("marble_shade", color="marble_shade"),
                   overhang=0.05)
    else:
        # Le temple du dieu des mers : toit de tuiles de marbre, comme taillé dans l'écume.
        prism_roof(x0, y0, x1, y1, z + hcol + 0.22, 0.46, along="y", pediment=M("marble_shade", color="marble_shade"),
                   overhang=0.05, tile_mat=M("tuiles_marbre", color="#e4ddd0", noise=0.06, scale=12),
                   material=M("toit_marbre", color="#d9d0bd", noise=0.05))
    # Fronton peint : bande colorée sous le toit, acrotères dorés.
    tbox(x0 + 0.1, y1 + 0.03, z + hcol + 0.24, x1 - 0.1, y1 + 0.05, z + hcol + 0.3, M(frieze, color=frieze))
    gold = M("gold", color="gold", rough=0.35)
    for y in (y0, y1):
        sphere((x0 + x1) / 2, y, z + hcol + 0.72, 0.06, gold)
    # Autel des sacrifices devant la façade.
    tbox(3.25, 3.1, 0.012, 3.8, 3.55, 0.24, M("marble"), bevel=0.01)
    tbox(3.23, 3.08, 0.24, 3.82, 3.57, 0.28, M(frieze, color=frieze))
    fire(3.52, 3.32, 0.28, s=2.2)
    if god == "athena":
        # Athéna Promachos, de bronze doré, lance levée ; l'olivier et la chouette.
        tbox(3.3, 1.0, 0.012, 3.7, 1.4, 0.32, M("marble"), bevel=0.01)
        statue(3.5, 1.2, 0.32, s=3.2, pose=0, material="gold")
        olive_tree(3.55, 2.2, 0.012, s=2.0, seed=8)
        sphere(3.5, 0.45, 0.32, 0.04, M("chouette", color="#8a7a5c", noise=0.1), sz=0.05)
        tbox(3.42, 0.37, 0.012, 3.58, 0.53, 0.28, M("marble"))
    else:
        # Trident de bronze colossal, bassin d'eau de mer, deux chevaux de marbre.
        bronze = M("bronze", color="#b08440", rough=0.35)
        tbox(3.3, 1.0, 0.012, 3.7, 1.4, 0.25, M("marble"), bevel=0.01)
        cyl(3.5, 1.2, 0.25, 1.35, 0.02, bronze, verts=8)
        tbox(3.4, 1.18, 1.2, 3.6, 1.22, 1.24, bronze)
        for d in (-0.1, 0.0, 0.1):
            cyl(3.5 + d, 1.2, 1.22, 1.45 if d == 0 else 1.38, 0.012, bronze, verts=6, r_top=0.003)
        tbox(3.15, 1.85, 0.012, 3.85, 2.75, 0.08, M("marble"))
        water_surface(3.2, 1.9, 3.8, 2.7, 0.075)
        for k, y in enumerate((0.3, 0.7)):
            m = M("cheval", color="marble", noise=0.03)
            tbox(3.35, y, 0.012, 3.7, y + 0.12, 0.1, m)
            tbox(3.38, y + 0.01, 0.1, 3.62, y + 0.11, 0.2, m)
            tbox(3.58, y + 0.02, 0.2, 3.68, y + 0.1, 0.32, m)
    cypress(0.12, 3.9, h=0.9, seed=5)
    for k in range(4):
        bush(0.6 + k * 0.5, 3.92, 0.012, 1.0, seed=k, color="leaf_olive")


for _god, _id in (("athena", "parthenon"), ("poseidon", "temple_poseidon")):
    for _s in range(3):
        BUILDINGS["%s_s%d" % (_id, _s)] = ((lambda s, g: lambda: _great_temple(s, g))(_s, _god), 4)
    BUILDINGS[_id] = ((lambda g: lambda: _great_temple(3, g))(_god), 4)


# --------------------------------------------------------------------------- Présents des dieux (2x2)

@building("sacred_olive", 2)
def sacred_olive():
    """L'olivier qu'Athéna a fait jaillir du rocher, dans son enclos de marbre, avec un petit autel."""
    _rock_pad(2, seed=11)
    paving(0.15, 0.15, 1.85, 1.85, z=0.012, material="marble_shade", scale=12)
    rubble_wall(0.15, 1.82, 1.85, 1.82, h=0.12, seed=1)
    rubble_wall(1.82, 0.15, 1.82, 1.85, h=0.12, seed=2)
    olive_tree(0.95, 0.9, 0.027, s=4.0, seed=12)
    olive_tree(0.55, 1.4, 0.027, s=1.6, seed=13)
    tbox(1.35, 1.3, 0.027, 1.65, 1.6, 0.2, M("marble"), bevel=0.01)
    tbox(1.33, 1.28, 0.2, 1.67, 1.62, 0.23, M("cloth_red", color="cloth_red"))
    fire(1.5, 1.45, 0.23, s=1.4)
    for k in range(3):
        sphere(0.35 + k * 0.12, 1.65, 0.05, 0.03, M("offrande", color="#c9a24a", noise=0.1), sz=0.025)


@building("salt_spring", 2)
def salt_spring():
    """La source que le trident de Poséidon a fait jaillir : rocher fendu, bassin d'eau de mer, trident planté."""
    _rock_pad(2, seed=13)
    rock = M("rocher_fendu", color="#bfae88", noise=0.25, bump=0.6, scale=10)
    for k, (x, y, s) in enumerate(((0.45, 0.45, 0.32), (0.85, 0.35, 0.22), (0.3, 0.9, 0.22))):
        sphere(x, y, 0.08, s, rock, sz=s * 0.6, seg=8, rings=5)
    marble = M("marble")
    tbox(0.6, 0.6, 0.012, 1.75, 1.75, 0.12, marble, bevel=0.01)
    water_surface(0.66, 0.66, 1.69, 1.69, 0.135)
    tbox(0.58, 0.58, 0.12, 1.77, 0.66, 0.15, M("aegean", color="aegean"))
    tbox(0.58, 0.58, 0.12, 0.66, 1.77, 0.15, M("aegean", color="aegean"))
    bronze = M("bronze", color="#b08440", rough=0.35)
    cyl(0.55, 0.6, 0.1, 0.95, 0.014, bronze, verts=8)
    tbox(0.47, 0.585, 0.85, 0.63, 0.615, 0.88, bronze)
    for d in (-0.07, 0.0, 0.07):
        cyl(0.55 + d, 0.6, 0.86, 1.05 if d == 0 else 1.0, 0.009, bronze, verts=6, r_top=0.002)
    for k in range(5):
        sphere(1.85, 0.4 + k * 0.28, 0.03, 0.035, M("coquillage", color="#efe2cc", noise=0.1), sz=0.02)
