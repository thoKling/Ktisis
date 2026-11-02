"""Rochers de montagne (assets/props/rock_<n>.png) : escarpements de calcaire en strates, éboulis et maquis.

Chaque variante tient sur une tuile. Les blocs sont des enveloppes convexes de points tirés au hasard :
des facettes nettes, que le trait Freestyle souligne, plutôt que des galets ronds.
"""

import math
import random

import bmesh
import bpy
from mathutils import Vector

from buildings import PROPS
from kit import M, T, _link, bush, cypress, olive_tree, pebbles, tufts

TONES = (
    (("calcaire", "#ada696"), ("calcaire_ombre", "#958e7e"), ("calcaire_clair", "#bdb6a4")),
    (("ocre", "#b3a68e"), ("ocre_ombre", "#998d76"), ("ocre_clair", "#c2b59c")),
)
ROCK_VARIANTS = 6


def _stone(tone, k):
    name, color = TONES[tone % len(TONES)][k % 3]
    return M(name, color=color, noise=0.16, scale=14, bump=0.7)


def block(tx, ty, z, rx, ry, h, material, seed=0, taper=0.3, rings=3, sides=6):
    """Bloc de roche anguleux : anneaux de points de moins en moins larges, enveloppe convexe."""
    rnd = random.Random(seed)
    pts = []
    for r in range(rings + 1):
        f = r / rings
        s = 1.0 - taper * f
        zz = z + h * f + (rnd.uniform(-0.12, 0.08) * h if 0 < r < rings else 0.0)
        a0 = rnd.uniform(0, 6.283)
        for i in range(sides):
            a = a0 + 6.283 * i / sides + rnd.uniform(-0.3, 0.3)
            j = rnd.uniform(0.75, 1.1)
            pts.append(Vector(T(tx + rx * s * j * math.cos(a), ty + ry * s * j * math.sin(a), zz)))
    top = z + h * rnd.uniform(1.0, 1.12)
    pts.append(Vector(T(tx + rnd.uniform(-0.3, 0.3) * rx, ty + rnd.uniform(-0.3, 0.3) * ry, top)))
    me = bpy.data.meshes.new("roc")
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("roc", me)
    bpy.context.scene.collection.objects.link(o)
    return _link(o, material)


def pillar(tx, ty, r, h, tone, seed=0):
    """Pilier de calcaire en strates : dalles empilées, légèrement décalées, sommet en pointe brisée."""
    rnd = random.Random(seed)
    n = max(1, int(round(h / 0.13)))
    z = 0.0
    for k in range(n):
        last = k == n - 1
        lh = h / n * rnd.uniform(0.85, 1.15)
        rk = r * (1.0 - 0.1 * k) * rnd.uniform(0.9, 1.05)
        block(tx + rnd.uniform(-0.02, 0.02), ty + rnd.uniform(-0.02, 0.02), z, rk, rk * rnd.uniform(0.75, 0.95),
              lh * (1.5 if last else 1.0), _stone(tone, (k + seed) % 2 * 2 if not last else 0), seed=seed * 11 + k,
              taper=0.55 if last else rnd.uniform(0.05, 0.18), rings=2, sides=7)
        z += lh * 0.97


def crag(tx, ty, spread, h, seed=0, count=4, tone=0):
    """Escarpement : piliers serrés de hauteurs inégales (crête dentelée), les plus hauts au fond."""
    rnd = random.Random(seed)
    spots = []
    for k in range(count):
        a = 6.283 * k / count + rnd.uniform(-0.4, 0.4)
        d = spread * (0.0 if k == 0 else rnd.uniform(0.6, 1.0))
        spots.append((tx + d * math.cos(a), ty + d * math.sin(a)))
    spots.sort(key=lambda p: p[0] + p[1])
    for k, (x, y) in enumerate(spots):
        back = 1.0 - (x + y - tx - ty + spread * 2) / (spread * 4 + 1e-6) * 0.6
        hh = h * (1.0 if k == 0 else rnd.uniform(0.45, 0.85)) * back
        pillar(x, y, spread * rnd.uniform(0.55, 0.75) + 0.04, max(hh, 0.08), tone, seed=seed * 3 + k)


def scree(tx0, ty0, tx1, ty1, count, seed=0):
    """Éboulis : petits blocs anguleux au pied des rochers."""
    rnd = random.Random(seed)
    for k in range(count):
        r = rnd.uniform(0.025, 0.06)
        block(rnd.uniform(tx0, tx1), rnd.uniform(ty0, ty1), 0.0, r, r * rnd.uniform(0.7, 1.0), r * rnd.uniform(0.6, 1.1),
              _stone(rnd.randint(0, 1), rnd.randint(0, 2)), seed=seed * 13 + k, taper=0.4, rings=1, sides=5)


def maquis(tx, ty, s=1.0, seed=0):
    """Touffe de maquis : quelques buissons sombres serrés (lentisque, chêne kermès)."""
    rnd = random.Random(seed)
    for k in range(rnd.randint(2, 4)):
        bush(tx + rnd.uniform(-0.05, 0.05) * s, ty + rnd.uniform(-0.05, 0.05) * s, 0, s * rnd.uniform(0.7, 1.1),
             seed=seed * 5 + k, color=rnd.choice(["olive_dark", "olive", "#56652f"]))


def _rock(variant):
    seed = 101 + variant * 17
    rnd = random.Random(seed)
    kind = variant % 3
    tone = variant // 3
    if kind == 0:
        # Grand escarpement dentelé au fond, éboulis et maquis devant.
        crag(0.45, 0.42, 0.26, rnd.uniform(0.8, 0.95), seed=seed, count=6, tone=tone)
        scree(0.5, 0.62, 0.9, 0.9, 8, seed=seed)
        maquis(0.22, 0.78, 0.9, seed=seed)
        maquis(0.82, 0.35, 0.7, seed=seed + 4)
    elif kind == 1:
        # Deux massifs séparés par une faille où pousse un cyprès.
        crag(0.3, 0.55, 0.18, rnd.uniform(0.6, 0.72), seed=seed, count=4, tone=tone)
        crag(0.62, 0.28, 0.2, rnd.uniform(0.68, 0.8), seed=seed + 3, count=4, tone=tone)
        cypress(0.66, 0.7, h=rnd.uniform(0.42, 0.52), seed=seed)
        scree(0.5, 0.65, 0.9, 0.92, 6, seed=seed + 1)
        maquis(0.2, 0.25, 0.8, seed=seed + 2)
    else:
        # Croupe plus basse en gradins, olivier sauvage et maquis.
        crag(0.45, 0.42, 0.3, rnd.uniform(0.42, 0.52), seed=seed, count=6, tone=tone)
        olive_tree(0.78, 0.74, s=0.7, seed=seed)
        maquis(0.82, 0.22, 0.9, seed=seed + 1)
        maquis(0.2, 0.8, 0.8, seed=seed + 3)
        scree(0.4, 0.68, 0.7, 0.92, 5, seed=seed + 2)
    tufts(0.06, 0.06, 0.94, 0.94, count=12, seed=seed, color="#8a8a4c")
    pebbles(0.1, 0.1, 0.9, 0.9, count=8, seed=seed)


for _i in range(ROCK_VARIANTS):
    PROPS["rock_%d" % _i] = ((lambda i: lambda: _rock(i))(_i), 1)
