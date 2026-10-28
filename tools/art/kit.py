"""Boîte à outils Blender pour les sprites de Ktisis.

Chaque sprite est une petite scène 3D faite de primitives (murs, colonnes, toits de tuiles...),
rendue avec Cycles par une caméra orthographique isométrique 2:1, soleil en haut à gauche.

Repère : 1 unité Blender = 1 tuile. Le bâtiment de taille n occupe X dans [0, n] et Y dans [-n, 0]
(X = axe x des tuiles, Y = -axe y des tuiles), Z vers le haut. Le coin bas de l'emprise est (n, -n, 0).
"""

import math
import random

import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

# Rendu en 2x : le jeu dessine les sprites à l'échelle 0,5 pour rester net quand on zoome.
SCALE = 2
TILE_W = 64 * SCALE
PPU = TILE_W / math.sqrt(2.0)  # pixels par unité, horizontalement à l'écran

CAM_ROT = Euler((math.radians(60.0), 0.0, math.radians(45.0)))

# Palette commune (assets/README.md).
PAL = {
    "marble": "#efe9dc",
    "marble_shade": "#d9d0bd",
    "plaster": "#ece3cf",
    "plaster_warm": "#e6d3b0",
    "mudbrick": "#b98f62",
    "stone": "#b8ab95",
    "stone_dark": "#8f8472",
    "terracotta": "#c2673f",
    "terracotta_dark": "#9c4c2c",
    "ochre": "#d4a24c",
    "olive": "#7d8a3e",
    "olive_dark": "#55622a",
    "aegean": "#2f6f9f",
    "aegean_light": "#5b9cc7",
    "wood": "#8a5a34",
    "wood_dark": "#5e3b20",
    "thatch": "#c9a75e",
    "cloth_red": "#a8382c",
    "cloth_white": "#f0e8d6",
    "cloth_blue": "#3c6e9a",
    "gold": "#d8b04a",
    "dirt": "#b59a6b",
    "soil": "#7b5a3a",
    "water": "#3d86b8",
    "black": "#2a2420",
    "grass": "#8f9d55",
    "wheat": "#dcbc5c",
    "leaf": "#6e8240",
    "leaf_olive": "#8c9a68",
    "cypress": "#3f5a32",
}


def hex_rgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    # sRGB -> linéaire
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c) + (1.0,)


# --------------------------------------------------------------------------- scène

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.filter_size = 1.2
    world = bpy.data.worlds.new("ciel")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = hex_rgb("#c4d6ea")
    bg.inputs[1].default_value = 0.55
    # Soleil chaud en haut à gauche de l'écran : ombres vers la droite et un peu vers le bas.
    sun = bpy.data.lights.new("soleil", "SUN")
    sun.energy = 3.6
    sun.color = (1.0, 0.94, 0.82)
    sun.angle = math.radians(2.0)
    o = bpy.data.objects.new("soleil", sun)
    sc.collection.objects.link(o)
    light_from = Vector((-1.0, -0.45, 1.25)).normalized()
    o.rotation_euler = light_from.to_track_quat("Z", "Y").to_euler()


def render(path, n, height_px=None, crop=True, ground=True, extra_w=0):
    """Rend la scène dans path. Largeur 64·n (·SCALE), bas de l'image = coin bas de l'emprise."""
    sc = bpy.context.scene
    w = int(TILE_W * n + extra_w)
    h = height_px or int(TILE_W * n * 2)
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.ortho_scale = w / PPU
    cam_data.clip_start = 0.1
    cam_data.clip_end = 200
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    rot = CAM_ROT.to_matrix()
    up = rot @ Vector((0, 1, 0))
    fwd = rot @ Vector((0, 0, -1))
    bottom = Vector((n, -n, 0.0))
    cam.location = bottom + up * (h * 0.5 / PPU) - fwd * 60.0
    cam.rotation_euler = CAM_ROT
    sc.camera = cam
    if ground:
        bpy.ops.mesh.primitive_plane_add(size=60, location=(n / 2, -n / 2, -0.001))
        g = bpy.context.object
        g.is_shadow_catcher = True
        g.name = "sol_ombres"
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if crop:
        _crop_top(path)


def _crop_top(path):
    from PIL import Image, ImageEnhance
    img = Image.open(path)
    # Couleurs un peu plus franches : rendu illustré plutôt que photo.
    rgb_, a = img.convert("RGB"), img.getchannel("A")
    rgb_ = ImageEnhance.Contrast(ImageEnhance.Color(rgb_).enhance(1.18)).enhance(1.06)
    img = rgb_.convert("RGBA")
    img.putalpha(a)
    a = img.getchannel("A").point(lambda v: 255 if v > 20 else 0)
    box = a.getbbox()
    if box:
        img.crop((0, max(0, box[1] - 4), img.width, img.height)).save(path)


# --------------------------------------------------------------------------- matériaux

_MATS = {}


def mat(name, color=None, rough=0.85, noise=0.08, bump=0.0, scale=40.0, kind=None, emit=0.0, alpha=1.0):
    """Matériau mat avec légère variation de teinte (aspect peint, pas réaliste)."""
    key = (name, color, rough, noise, bump, scale, kind, emit, alpha)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    base = hex_rgb(PAL.get(color, color) if color else PAL.get(name, "#ff00ff"))
    bsdf.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.25
    tex = nt.nodes.new("ShaderNodeTexCoord")
    if kind == "brick":
        # Appareil de pierres taillées : joints sombres, blocs légèrement différents.
        br = nt.nodes.new("ShaderNodeTexBrick")
        br.inputs["Scale"].default_value = scale
        br.inputs["Mortar Size"].default_value = 0.025
        br.inputs["Brick Width"].default_value = 0.6
        br.inputs["Row Height"].default_value = 0.3
        c1 = Vector(base[:3])
        br.inputs["Color1"].default_value = tuple(c1 * 1.03) + (1,)
        br.inputs["Color2"].default_value = tuple(c1 * 0.9) + (1,)
        br.inputs["Mortar"].default_value = tuple(c1 * 0.62) + (1,)
        br.offset = 0.5
        mp = nt.nodes.new("ShaderNodeMapping")
        nt.links.new(tex.outputs["Object"], mp.inputs[0])
        nt.links.new(mp.outputs[0], br.inputs[0])
        nt.links.new(br.outputs["Color"], bsdf.inputs["Base Color"])
    elif noise > 0:
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = scale
        nz.inputs["Detail"].default_value = 3.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        c = Vector(base[:3])
        ramp.color_ramp.elements[0].color = tuple(c * (1 - noise)) + (1,)
        ramp.color_ramp.elements[1].color = tuple(c * (1 + noise)) + (1,)
        ramp.color_ramp.elements[0].position = 0.3
        ramp.color_ramp.elements[1].position = 0.7
        nt.links.new(tex.outputs["Object"], nz.inputs[0])
        nt.links.new(nz.outputs["Fac"], ramp.inputs[0])
        nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = base
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = base
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
    if bump > 0:
        nz2 = nt.nodes.new("ShaderNodeTexNoise")
        nz2.inputs["Scale"].default_value = scale * 2
        bp = nt.nodes.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = bump
        nt.links.new(tex.outputs["Object"], nz2.inputs[0])
        nt.links.new(nz2.outputs["Fac"], bp.inputs["Height"])
        nt.links.new(bp.outputs["Normal"], bsdf.inputs["Normal"])
    _MATS[key] = m
    return m


def M(name, **kw):
    return mat(name, **kw)


# --------------------------------------------------------------------------- primitives

def _link(obj, material):
    if material is not None:
        if isinstance(material, str):
            material = M(material)
        obj.data.materials.append(material)
    return obj


def box(x0, y0, z0, x1, y1, z1, material=None, bevel=0.0):
    """Pavé aligné sur les axes, entre deux coins (repère : X tuiles, Y = -y tuiles)."""
    x0, x1 = min(x0, x1), max(x0, x1)
    y0, y1 = min(y0, y1), max(y0, y1)
    z0, z1 = min(z0, z1), max(z0, z1)
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.object
    o.scale = (x1 - x0, y1 - y0, z1 - z0)
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        md = o.modifiers.new("b", "BEVEL")
        md.width = bevel
        md.segments = 1
    return _link(o, material)


def tbox(tx0, ty0, z0, tx1, ty1, z1, material=None, bevel=0.0):
    """Pavé en coordonnées de tuiles (x, y), y vers le bas-gauche de l'écran."""
    return box(tx0, -ty0, z0, tx1, -ty1, z1, material, bevel)


def cyl(tx, ty, z0, z1, r, material=None, verts=12, r_top=None):
    h = z1 - z0
    if r_top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=(tx, -ty, z0 + h / 2))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r_top, depth=h, location=(tx, -ty, z0 + h / 2))
    o = bpy.context.object
    bpy.ops.object.shade_smooth()
    return _link(o, material)


def sphere(tx, ty, z, r, material=None, sz=None, seg=10, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=(tx, -ty, z))
    o = bpy.context.object
    if sz is not None:
        o.scale = (1, 1, sz / r)
        bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    return _link(o, material)


def blob(tx, ty, z, r, material=None, seed=0, sz=None, lumps=0.25):
    """Feuillage : sphère cabossée."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=(tx, -ty, z))
    o = bpy.context.object
    rnd = random.Random(seed)
    for v in o.data.vertices:
        v.co *= 1.0 + rnd.uniform(-lumps, lumps)
    if sz is not None:
        o.scale = (1, 1, sz / r)
        bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_flat()
    return _link(o, material)


def mesh(verts, faces, material=None, smooth=False, name="m"):
    me = bpy.data.meshes.new(name)
    me.from_pydata([Vector(v) for v in verts], [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    return _link(o, material)


def T(tx, ty, z=0.0):
    """Point en coordonnées de tuiles vers le repère Blender."""
    return (tx, -ty, z)


def prism_roof(tx0, ty0, tx1, ty1, z, rise, along="x", material="terracotta", overhang=0.06, tiles=True,
               tile_mat=None, pediment=None):
    """Toit à deux pans. along = axe du faîtage ('x' ou 'y'). Tuiles rondes (imbrex) en relief."""
    o = overhang
    x0, x1, y0, y1 = tx0 - o, tx1 + o, ty0 - o, ty1 + o
    if along == "x":
        ym = (y0 + y1) / 2
        v = [T(x0, y0, z), T(x1, y0, z), T(x1, ym, z + rise), T(x0, ym, z + rise), T(x0, y1, z), T(x1, y1, z)]
        f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2)]
    else:
        xm = (x0 + x1) / 2
        v = [T(x0, y0, z), T(x0, y1, z), T(xm, y1, z + rise), T(xm, y0, z + rise), T(x1, y0, z), T(x1, y1, z)]
        f = [(0, 3, 2, 1), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5)]
    r = mesh(v, f, material if tiles else material)
    # Pignons : murs triangulaires (fronton) en dessous du débord.
    if pediment:
        pm = pediment
        if along == "x":
            for xx in (tx0, tx1):
                mesh([T(xx, ty0, z), T(xx, (ty0 + ty1) / 2, z + rise * 0.96), T(xx, ty1, z)], [(0, 1, 2)], pm)
        else:
            for yy in (ty0, ty1):
                mesh([T(tx0, yy, z), T((tx0 + tx1) / 2, yy, z + rise * 0.96), T(tx1, yy, z)], [(0, 1, 2)], pm)
    if tiles:
        _imbrices(x0, y0, x1, y1, z, rise, along, tile_mat or M("terracotta", color="terracotta", noise=0.12, scale=12))
    return r


def _imbrices(x0, y0, x1, y1, z, rise, along, material):
    """Rangées de tuiles couvre-joints, du faîtage à l'égout, sur les deux pans."""
    step = 0.11
    rad = 0.022
    if along == "x":
        ym = (y0 + y1) / 2
        n = int((x1 - x0) / step)
        off = (x1 - x0 - (n - 1) * step) / 2
        for i in range(n):
            x = x0 + off + i * step
            for ya, yb in ((y0, ym), (y1, ym)):
                _tile_row(T(x, ya, z), T(x, yb, z + rise), rad, material)
        _tile_row(T(x0, ym, z + rise), T(x1, ym, z + rise), rad * 1.6, material)
    else:
        xm = (x0 + x1) / 2
        n = int((y1 - y0) / step)
        off = (y1 - y0 - (n - 1) * step) / 2
        for i in range(n):
            y = y0 + off + i * step
            for xa, xb in ((x0, xm), (x1, xm)):
                _tile_row(T(xa, y, z), T(xb, y, z + rise), rad, material)
        _tile_row(T(xm, y0, z + rise), T(xm, y1, z + rise), rad * 1.6, material)


def _tile_row(a, b, r, material):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.shade_smooth()
    _link(o, material)


def hip_roof(tx0, ty0, tx1, ty1, z, rise, material="terracotta", overhang=0.06):
    """Toit en croupe (quatre pans), tuiles suggérées par des rangées en relief."""
    o = overhang
    x0, x1, y0, y1 = tx0 - o, tx1 + o, ty0 - o, ty1 + o
    w, d = x1 - x0, y1 - y0
    if w >= d:
        r = d / 2
        a, b = T(x0 + r, (y0 + y1) / 2, z + rise), T(x1 - r, (y0 + y1) / 2, z + rise)
    else:
        r = w / 2
        a, b = T((x0 + x1) / 2, y0 + r, z + rise), T((x0 + x1) / 2, y1 - r, z + rise)
    c = [T(x0, y0, z), T(x1, y0, z), T(x1, y1, z), T(x0, y1, z)]
    if w >= d:
        v = c + [a, b]
        f = [(0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4)]
    else:
        v = c + [a, b]
        f = [(0, 1, 4), (1, 2, 5, 4), (2, 3, 5), (3, 0, 4, 5)]
    m = M(material, color=material, noise=0.12, scale=14) if isinstance(material, str) else material
    mesh(v, f, m)
    # Lignes de tuiles : petites arêtes parallèles à l'égout, sur chaque pan.
    tm = M("terracotta_dark", color="terracotta_dark", noise=0.05)
    rows = max(2, int(rise / 0.07))
    for k in range(1, rows):
        t = k / rows
        zz = z + rise * t
        ins = r * t
        pts = [T(x0 + ins, y0 + ins, zz), T(x1 - ins, y0 + ins, zz), T(x1 - ins, y1 - ins, zz), T(x0 + ins, y1 - ins, zz)]
        for i in range(4):
            p, q = Vector(pts[i]), Vector(pts[(i + 1) % 4])
            if (q - p).length > 0.02:
                _tile_row(p, q, 0.012, tm)


def column(tx, ty, z0, h, r=0.045, material="marble", doric=True):
    m = M(material, color=material, noise=0.04)
    cyl(tx, ty, z0, z0 + h * 0.94, r, m, verts=12, r_top=r * 0.85)
    if doric:
        cyl(tx, ty, z0 + h * 0.92, z0 + h * 0.96, r * 1.25, m, verts=12, r_top=r * 1.5)
        tbox(tx - r * 1.6, ty - r * 1.6, z0 + h * 0.96, tx + r * 1.6, ty + r * 1.6, z0 + h, m)


def colonnade(tx0, ty0, tx1, ty1, z0, h, count, r=0.045, material="marble"):
    for i in range(count):
        t = i / (count - 1) if count > 1 else 0.5
        column(tx0 + (tx1 - tx0) * t, ty0 + (ty1 - ty0) * t, z0, h, r, material)


def entablature(tx0, ty0, tx1, ty1, z, h=0.12, material="marble", frieze="aegean"):
    """Architrave + frise de triglyphes (bandes sombres régulières) + corniche."""
    m = M(material, color=material, noise=0.03)
    tbox(tx0, ty0, z, tx1, ty1, z + h * 0.4, m)
    tbox(tx0, ty0, z + h * 0.4, tx1, ty1, z + h * 0.8, M("frise", color=PAL["marble_shade"], noise=0.02))
    # triglyphes sur les deux faces visibles (y max et x max)
    fm = M(frieze, color=frieze, noise=0.02)
    step = 0.12
    nx = int((tx1 - tx0) / step)
    for i in range(nx + 1):
        x = tx0 + (tx1 - tx0) * i / max(nx, 1)
        tbox(x - 0.018, ty1 - 0.005, z + h * 0.42, x + 0.018, ty1 + 0.008, z + h * 0.78, fm)
    ny = int((ty1 - ty0) / step)
    for i in range(ny + 1):
        y = ty0 + (ty1 - ty0) * i / max(ny, 1)
        tbox(tx1 - 0.005, y - 0.018, z + h * 0.42, tx1 + 0.008, y + 0.018, z + h * 0.78, fm)
    tbox(tx0 - 0.03, ty0 - 0.03, z + h * 0.8, tx1 + 0.03, ty1 + 0.03, z + h, m)


def steps(tx0, ty0, tx1, ty1, z0, n=3, rise=0.035, inset=0.04, material="marble"):
    m = M(material, color=material, noise=0.04)
    for i in range(n):
        d = inset * i
        tbox(tx0 + d, ty0 + d, z0 + rise * i, tx1 - d, ty1 - d, z0 + rise * (i + 1), m)
    return z0 + rise * n


def ground_pad(n, material="dirt", inset=0.02, h=0.01):
    tbox(inset, inset, 0, n - inset, n - inset, h, M(material, color=material, noise=0.15, scale=8))


def paving(tx0, ty0, tx1, ty1, z=0.0, h=0.015, material="stone", scale=18):
    tbox(tx0, ty0, z, tx1, ty1, z + h, M(material + "_pav", color=material, kind="brick", scale=scale))


def window(face, a, z0, z1, material="black"):
    """Petite ouverture sombre sur une face visible : face = ('y', y_val, x_center) ou ('x', x_val, y_center)."""
    m = M(material, color=material, noise=0.0)
    if face[0] == "y":
        y, xc = face[1], face[2]
        tbox(xc - a, y - 0.005, z0, xc + a, y + 0.012, z1, m)
    else:
        x, yc = face[1], face[2]
        tbox(x - 0.005, yc - a, z0, x + 0.012, yc + a, z1, m)


def amphora(tx, ty, z=0.0, s=1.0, material="terracotta"):
    m = M(material, color=material, noise=0.1)
    sphere(tx, ty, z + 0.05 * s, 0.035 * s, m, sz=0.05 * s)
    cyl(tx, ty, z + 0.08 * s, z + 0.12 * s, 0.012 * s, m)
    cyl(tx, ty, z, z + 0.02 * s, 0.01 * s, m)


def cypress(tx, ty, z=0.0, h=0.6, seed=0):
    m = M("cypress", color="cypress", noise=0.15, scale=20)
    cyl(tx, ty, z, z + 0.06, 0.02, M("wood_dark"))
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=h * 0.17, radius2=0.0, depth=h, location=(tx, -ty, z + 0.05 + h / 2))
    o = bpy.context.object
    rnd = random.Random(seed)
    for v in o.data.vertices:
        v.co.x *= 1 + rnd.uniform(-0.15, 0.15)
        v.co.y *= 1 + rnd.uniform(-0.15, 0.15)
    sm = o.modifiers.new("s", "SUBSURF")
    sm.levels = 1
    _link(o, m)


def olive_tree(tx, ty, z=0.0, s=1.0, seed=0):
    rnd = random.Random(seed)
    trunk = M("wood_dark", color="wood_dark", noise=0.1)
    cyl(tx, ty, z, z + 0.16 * s, 0.025 * s, trunk, verts=6, r_top=0.018 * s)
    leaf = M("leaf_olive", color="leaf_olive", noise=0.18, scale=25)
    for k in range(4):
        dx, dy = rnd.uniform(-0.07, 0.07) * s, rnd.uniform(-0.07, 0.07) * s
        blob(tx + dx, ty + dy, z + (0.2 + rnd.uniform(0, 0.06)) * s, 0.08 * s, leaf, seed=seed * 7 + k, sz=0.06 * s)


def leafy_tree(tx, ty, z=0.0, s=1.0, seed=0, color="leaf"):
    rnd = random.Random(seed)
    cyl(tx, ty, z, z + 0.2 * s, 0.03 * s, M("wood_dark"), verts=6)
    leaf = M(color, color=color, noise=0.2, scale=22)
    for k in range(3):
        dx, dy = rnd.uniform(-0.06, 0.06) * s, rnd.uniform(-0.06, 0.06) * s
        blob(tx + dx, ty + dy, z + (0.3 + rnd.uniform(0, 0.1)) * s, 0.13 * s, leaf, seed=seed * 5 + k)


def bush(tx, ty, z=0.0, s=1.0, seed=0, color="leaf"):
    blob(tx, ty, z + 0.04 * s, 0.06 * s, M(color, color=color, noise=0.2, scale=25), seed=seed, sz=0.05 * s)


def crate(tx, ty, z=0.0, s=0.08):
    tbox(tx - s / 2, ty - s / 2, z, tx + s / 2, ty + s / 2, z + s, M("wood", color="wood", noise=0.1), bevel=0.004)


def awning(tx0, ty0, tx1, ty1, z_hi, z_lo, along="x", colors=("cloth_red", "cloth_white"), stripes=6):
    """Auvent de toile rayée incliné vers l'avant (vers y max si along = 'x')."""
    for i in range(stripes):
        c = colors[i % len(colors)]
        m = M(c, color=c, noise=0.04)
        if along == "x":
            a = tx0 + (tx1 - tx0) * i / stripes
            b = tx0 + (tx1 - tx0) * (i + 1) / stripes
            mesh([T(a, ty0, z_hi), T(b, ty0, z_hi), T(b, ty1, z_lo), T(a, ty1, z_lo)], [(0, 1, 2, 3)], m)
        else:
            a = ty0 + (ty1 - ty0) * i / stripes
            b = ty0 + (ty1 - ty0) * (i + 1) / stripes
            mesh([T(tx0, a, z_hi), T(tx0, b, z_hi), T(tx1, b, z_lo), T(tx1, a, z_lo)], [(0, 1, 2, 3)], m)


def post(tx, ty, z0, z1, r=0.012, material="wood"):
    cyl(tx, ty, z0, z1, r, M(material, color=material, noise=0.1), verts=6)


def statue(tx, ty, z0=0.0, s=1.0, material="marble", pose=0):
    """Silhouette humaine stylisée sur piédestal."""
    m = M(material, color=material, noise=0.03)
    tbox(tx - 0.07 * s, ty - 0.07 * s, z0, tx + 0.07 * s, ty + 0.07 * s, z0 + 0.12 * s, m, bevel=0.005)
    z = z0 + 0.12 * s
    cyl(tx, ty, z, z + 0.14 * s, 0.035 * s, m, verts=10, r_top=0.03 * s)  # drapé
    cyl(tx, ty, z + 0.14 * s, z + 0.22 * s, 0.032 * s, m, verts=10, r_top=0.026 * s)  # torse
    sphere(tx, ty, z + 0.25 * s, 0.022 * s, m)
    if pose == 0:  # bras levé tenant une lance
        cyl(tx + 0.04 * s, ty, z, z + 0.34 * s, 0.006 * s, m, verts=6)
    else:
        cyl(tx - 0.035 * s, ty + 0.01 * s, z + 0.12 * s, z + 0.21 * s, 0.01 * s, m, verts=6)


def fire(tx, ty, z, s=1.0):
    m = M("feu", color="#ffb347", emit=6.0, noise=0.0)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.03 * s, radius2=0.0, depth=0.08 * s, location=(tx, -ty, z + 0.04 * s))
    _link(bpy.context.object, m)
    m2 = M("braise", color="#ff6a2a", emit=4.0, noise=0.0)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.02 * s, radius2=0.0, depth=0.05 * s, location=(tx + 0.02 * s, -ty + 0.01 * s, z + 0.025 * s))
    _link(bpy.context.object, m2)


def water_surface(tx0, ty0, tx1, ty1, z):
    tbox(tx0, ty0, z - 0.01, tx1, ty1, z, M("eau", color="water", rough=0.15, noise=0.12, scale=30))
