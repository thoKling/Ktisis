"""Seconde passe de détails sur les bâtiments de service et de production : de la vie autour des murs."""

import random

from buildings import BUILDINGS
from kit import (M, amphora, awning, bush, chicken, crate, cyl, dado, laundry, olive_tree, pebbles, pergola, pithos,
                 post, potted_plant, rubble_wall, sphere, tbox, tufts, _beam, T)
from mathutils import Vector


def extra(name):
    def deco(fn):
        base, size = BUILDINGS[name]

        def both():
            base()
            fn()
        BUILDINGS[name] = (both, size)
        return fn
    return deco


def sacks(x, y, n=4, seed=0):
    rnd = random.Random(seed)
    for k in range(n):
        sphere(x + (k % 3) * 0.08 + rnd.uniform(-0.01, 0.01), y + (k // 3) * 0.08, 0.04 + (k // 3) * 0.0, 0.045,
               M("sac", color="#d8c39a", noise=0.12, bump=0.3), sz=0.04)


def tripod(x, y, z=0.0):
    """Trépied de bronze à offrandes."""
    br = M("bronze", color="#b08440", rough=0.35)
    for d in ((-0.03, 0), (0.02, 0.025), (0.02, -0.025)):
        _beam(Vector(T(x + d[0], y + d[1], z)), Vector(T(x, y, z + 0.18)), 0.005, br)
    cyl(x, y, z + 0.16, z + 0.2, 0.045, br, verts=14, r_top=0.055)


@extra("granary")
def granary_more():
    dado(("y", 1.48), 0.17, 2.18, 0.12, 0.18, "#a8382c")
    dado(("x", 2.18), 0.17, 1.48, 0.12, 0.18, "#a8382c")
    for x in (0.8, 1.9):
        post(x, 1.95, 0, 0.3)
    awning(0.6, 1.5, 2.0, 2.0, 0.42, 0.3, along="x", colors=("cloth_white", "ochre"), stripes=8)
    sacks(0.95, 1.65, 6, 1)
    for k in range(4):
        pithos(2.4 + (k % 2) * 0.15, 1.75 + (k // 2) * 0.15, s=0.9)
    chicken(1.2, 2.5)
    chicken(1.35, 2.65, color="#a0623a")
    rubble_wall(0.05, 2.92, 2.95, 2.92, h=0.1, seed=7)


@extra("farm")
def farm_more():
    rubble_wall(0.05, 2.93, 1.45, 2.93, h=0.1, seed=3)
    rubble_wall(1.95, 0.05, 1.95, 1.9, h=0.1, seed=4)
    for k in range(3):
        olive_tree(2.85, 1.0 + k * 0.4, s=0.9, seed=20 + k)
    laundry(2.1, 1.0, 2.8, 1.0, z=0.24, seed=2)
    pithos(2.85, 0.4, s=0.8)
    chicken(2.5, 1.9)
    chicken(2.6, 2.05, color="#a0623a")


@extra("warehouse")
def warehouse_more():
    dado(("y", 1.68), 0.14, 1.88, 0.1, 0.16, "#7a2a22")
    sacks(1.0, 2.35, 5, 3)
    for k in range(3):
        pithos(0.3 + k * 0.15, 2.6, s=0.9)
    potted_plant(1.6, 1.85, seed=1, flower="#d9b13b")


@extra("press")
def press_more():
    dado(("y", 1.0), 0.1, 1.2, 0.0, 0.1, "#5b7a3a")
    dado(("x", 1.2), 0.1, 1.0, 0.0, 0.1, "#5b7a3a")
    pergola(1.25, 1.1, 1.85, 1.85, h=0.3, seed=6)
    for k in range(3):
        pithos(1.4 + k * 0.15, 1.5, s=0.85)
    for k in range(4):
        cyl(0.25 + k * 0.12, 1.8, 0, 0.05, 0.045, M("osier", color="#b8925a", noise=0.1), verts=10)
        sphere(0.25 + k * 0.12, 1.8, 0.05, 0.04, M("olives", color="#4a5228", noise=0.1), sz=0.02)


@extra("woodcutter")
def woodcutter_more():
    rnd = random.Random(2)
    for k in range(4):
        x, y = rnd.uniform(1.2, 1.9), rnd.uniform(1.3, 1.9)
        cyl(x, y, 0, 0.06, 0.05, M("souche", color="#a07a4a", noise=0.1), verts=10)
    tbox(1.1, 1.55, 0.1, 1.5, 1.6, 0.12, M("wood"))
    for x in (1.15, 1.45):
        post(x, 1.57, 0, 0.11, r=0.01)
    laundry(0.2, 1.1, 0.95, 1.1, z=0.22, seed=4)


@extra("sheepfold")
def sheepfold_more():
    tufts(0.3, 1.0, 2.7, 2.7, 25, 5, color="#6f8a3a")
    for k in range(3):
        olive_tree(2.4 + (k % 2) * 0.2, 0.4 + k * 0.3, s=1.0, seed=30 + k)
    pithos(1.5, 0.6, s=0.8)


@extra("agora")
def agora_more():
    dado(("y", 0.45), 0.15, 2.85, 0.07, 0.13, "#a8382c")
    for k in range(3):
        pithos(2.75, 1.3 + k * 0.15, s=0.85)
    sacks(1.2, 2.55, 4, 9)
    for (x, y) in ((0.15, 1.1), (2.85, 1.0)):
        potted_plant(x, y, s=1.4, seed=int(x * 9), flower="#c4566e")
    tufts(0.05, 2.85, 2.9, 2.97, 8, 4)


@extra("tax_office")
def tax_more():
    potted_plant(0.25, 1.35, s=1.3, seed=2, flower="#d9b13b")
    potted_plant(1.6, 1.3, s=1.3, seed=3)


for _alt in ("altar_demeter", "altar_athena", "altar_poseidon", "altar_hera"):
    @extra(_alt)
    def _alt_more():
        tripod(0.35, 1.45, 0.015)
        tripod(1.25, 1.75, 0.015)
        for k in range(3):
            potted_plant(1.9, 1.0 + k * 0.15, s=1.1, seed=k, flower="#f1e6c4")


@extra("fishery")
def fishery_more():
    laundry(0.15, 1.95, 0.95, 1.95, z=0.2, seed=8)
    for k in range(3):
        cyl(1.1 + k * 0.1, 1.85, 0.0, 0.03, 0.05, M("corde_roul", color="#c9b48a", noise=0.1), verts=10)


@extra("plaza")
def plaza_more():
    # Bordure de dalles sombres et motif en damier autour du bassin.
    band = M("dalle_sombre", color="#a89a7e", kind="brick", scale=14)
    for (a, b, c, d) in ((0.12, 0.12, 1.88, 0.2), (0.12, 1.8, 1.88, 1.88), (0.12, 0.12, 0.2, 1.88), (1.8, 0.12, 1.88, 1.88)):
        tbox(a, b, 0.02, c, d, 0.024, band, bevel=0.001)
    for i in range(6):
        for j in range(6):
            if (i + j) % 2 == 0 and not (1 <= i <= 4 and 1 <= j <= 4):
                tbox(0.6 + i * 0.133, 0.6 + j * 0.133, 0.02, 0.733 + i * 0.133, 0.733 + j * 0.133, 0.023, M("dalle_rouge", color="#b06a4a", noise=0.05), bevel=0.001)
    for (x, y) in ((0.7, 0.25), (1.3, 0.25), (0.25, 0.7), (0.25, 1.3), (1.75, 0.7), (1.75, 1.3), (0.7, 1.75), (1.3, 1.75)):
        potted_plant(x, y, 0.02, s=1.2, seed=int(x * 10 + y * 3), flower=("#c4566e" if x < 1 else "#d9b13b"))
