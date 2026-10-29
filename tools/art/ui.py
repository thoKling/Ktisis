"""Habillage de l'interface, style « stèle de marbre » (numpy + Pillow) : python ui.py

Produit dans assets/ui/ :
- panel.png : marbre veiné, double filet et ombre portée (StyleBoxTexture, tuilé) ;
- button_*.png : pierre (normal, survol, désactivé) et terre cuite (enfoncé / actif) ;
- topbar.png : bandeau de marbre souligné de terre cuite ;
- frieze.png : méandre en terre cuite, à répéter en largeur ;
- icons/*.svg : icônes au trait blanc, teintées dans le jeu.
"""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui")

MARBLE = "#f2ece0"
VEIN = "#cbbfa6"
STONE_LINE = "#a8977a"
INNER_LIGHT = "#f8f4ec"
INNER_LINE = "#c9bb9f"
TERRA = "#a4462a"

PANEL_TILE = 128     # partie marbre, périodique
PANEL_BORDER = 6     # filets
PANEL_SHADOW = 6     # ombre autour du panneau


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def periodic_noise(n, freq_cut, seed):
    """Bruit lisse et périodique n x n (filtrage passe-bas d'un bruit blanc)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.standard_normal((n, n)))
    k = np.fft.fftfreq(n) * n
    kk = np.sqrt(k[:, None] ** 2 + k[None, :] ** 2)
    f *= np.exp(-(kk / freq_cut) ** 2)
    out = np.real(np.fft.ifft2(f))
    return (out - out.mean()) / (out.std() + 1e-6)


def marble(n):
    """Marbre clair à veines diagonales, raccordable dans les deux sens."""
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    warp = periodic_noise(n, 3.0, 1) * 1.6 + periodic_noise(n, 7.0, 2) * 0.5
    phase = 2 * np.pi * (x + y) / n * 2 + warp
    vein = np.exp(-np.abs(np.sin(phase)) * 9.0)
    fine = np.exp(-np.abs(np.sin(2 * np.pi * (x - y) / n * 3 + warp * 1.3)) * 18.0) * 0.4
    grain = periodic_noise(n, 30.0, 3) * 0.012 + periodic_noise(n, 6.0, 4) * 0.012
    t = np.clip(vein * 0.33 + fine * 0.25, 0, 1)[..., None]
    col = rgb(MARBLE) * (1 - t) + rgb(VEIN) * t
    col *= (1 + grain)[..., None]
    return np.clip(col, 0, 255).astype(np.uint8)


def panel():
    b, s = PANEL_BORDER, PANEL_SHADOW
    inner = PANEL_TILE + 2 * b
    size = inner + 2 * s
    shadow = Image.new("L", (size, size), 0)
    ImageDraw.Draw(shadow).rectangle([s, s + 2, s + inner - 1, s + inner + 1], fill=120)
    shadow = shadow.filter(ImageFilter.GaussianBlur(3))
    img = Image.new("RGBA", (size, size), (40, 25, 10, 0))
    img.putalpha(shadow)
    m = marble(PANEL_TILE)
    # Le marbre déborde sous les filets, et le centre est exactement une période : le tuilage est continu.
    full = np.tile(m, (2, 2, 1))[:inner, :inner]
    face = Image.fromarray(np.roll(full, (b, b), axis=(0, 1)))
    d = ImageDraw.Draw(face)
    d.rectangle([0, 0, inner - 1, inner - 1], outline=STONE_LINE)
    d.rectangle([1, 1, inner - 2, inner - 2], outline=INNER_LIGHT)
    d.rectangle([2, 2, inner - 3, inner - 3], outline=INNER_LIGHT)
    d.rectangle([3, 3, inner - 4, inner - 4], outline=INNER_LIGHT)
    d.rectangle([4, 4, inner - 5, inner - 5], outline=INNER_LINE)
    img.paste(face, (s, s))
    img.save(os.path.join(OUT, "panel.png"))


def gradient(w, h, top, bottom):
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    col = rgb(top) * (1 - t) + rgb(bottom) * t
    return np.repeat(col, w, axis=1)


def button(name, top, bottom, line, highlight):
    w = h = 40
    a = gradient(w, h, top, bottom)
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    if highlight:
        d.line([(1, 1), (w - 2, 1)], fill=highlight)
    d.rectangle([0, 0, w - 1, h - 1], outline=line)
    for c in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        img.putpixel(c, (0, 0, 0, 0))
    img.save(os.path.join(OUT, "button_%s.png" % name))


def topbar():
    w, h = 8, 60
    a = np.zeros((h, w, 4), dtype=np.float32)
    a[:50, :, :3] = gradient(w, 50, "#f4efe4", "#e3dac8")
    a[:50, :, 3] = 255
    a[49, :, :3] = rgb(STONE_LINE)
    a[50:53, :, :3] = rgb(TERRA)
    a[50:53, :, 3] = 255
    for i in range(7):
        a[53 + i, :, :3] = (40, 25, 10)
        a[53 + i, :, 3] = 90 * (1 - i / 7) ** 2
    Image.fromarray(a.astype(np.uint8)).save(os.path.join(OUT, "topbar.png"))


def frieze():
    k = 4
    img = Image.new("RGBA", (20 * k, 12 * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(0, 11), (20, 11)]
    key = [(3, 11), (3, 1.5), (15, 1.5), (15, 8), (7, 8), (7, 4.5), (11, 4.5)]
    w = int(1.6 * k)
    d.line([(x * k, y * k) for x, y in pts], fill=TERRA, width=w)
    d.line([(x * k, y * k) for x, y in key], fill=TERRA, width=w, joint="curve")
    img.resize((20, 12), Image.LANCZOS).save(os.path.join(OUT, "frieze.png"))


# --------------------------------------------------------------------------- icônes (viewBox 24)

ICONS = {
    "coin": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5.6"/><path d="M12 9.2 14.4 14H9.6z"/>',
    "pop": '<circle cx="9" cy="7" r="2.6"/><path d="M3.8 20c0-4.4 2.4-7.2 5.2-7.2s5.2 2.8 5.2 7.2"/>'
           '<circle cx="16.6" cy="8.2" r="2.1"/><path d="M15.3 13.3c3 .1 5 2.6 5 6.7"/>',
    "work": '<path d="m13.5 3.5 7 7-2.8 2.8-7-7z"/><path d="M12.2 7.8 3.8 16.2a1.8 1.8 0 0 0 2.5 2.5l8.4-8.4"/>',
    "moon": '<path d="M19.5 14.6A8 8 0 1 1 9.4 4.5a6.4 6.4 0 0 0 10.1 10.1z"/>',
    "cursor": '<path d="m5 3 13.5 7.2-6.2 1.4-2.8 6.1z"/>',
    "pick": '<path d="M4 11.5C6 6.5 10 4 15 4.5M15 4.5c2.8 2.2 4.6 5.4 4.5 9.5"/><path d="m13.6 6.4-9.4 13.4"/>',
    "road": '<path d="M8 3 4 21M16 3l4 18M12 4v3M12 10.5v3M12 17v3.5"/>',
    "house": '<path d="M2.8 11 12 4l9.2 7"/><path d="M5 9.6V20h14V9.6M10 20v-5h4v5"/>',
    "wheat": '<path d="M12 21V3"/><path d="M12 10.5c-2.6-.6-3.9-2.4-3.9-4.6 2.6.4 3.9 2.1 3.9 4.6zM12 10.5c2.6-.6 3.9-2.4 3.9-4.6-2.6.4-3.9 2.1-3.9 4.6z'
             'M12 15c-2.6-.6-3.9-2.4-3.9-4.6 2.6.4 3.9 2.1 3.9 4.6zM12 15c2.6-.6 3.9-2.4 3.9-4.6-2.6.4-3.9 2.1-3.9 4.6z"/>',
    "olive": '<path d="M4 20C9 15 14 10 20 4"/><path d="M9 15c-3 .2-4.6-1-5.2-3 2.6-.6 4.6.4 5.2 3zM13 11c-.2-3 1-4.6 3-5.2.6 2.6-.4 4.6-3 5.2z'
             'M15 9.4c3-.2 4.6 1 5.2 3-2.6.6-4.6-.4-5.2-3z"/><circle class="f" cx="11.2" cy="15.6" r="1.6"/><circle class="f" cx="7.4" cy="7.8" r="1.4"/>',
    "amph": '<path d="M9 3h6M10.2 3v3c-3.8 2-4.8 6-3.8 9.6.8 3 2.9 5.4 5.6 5.4s4.8-2.4 5.6-5.4c1-3.6 0-7.6-3.8-9.6V3"/>'
            '<path d="M8.6 7.2c-2.8-.3-3.2 3.4-1.2 4.6M15.4 7.2c2.8-.3 3.2 3.4 1.2 4.6"/>',
    "drop": '<path d="M12 3C9.2 7.8 6 10.8 6 14.6a6 6 0 0 0 12 0C18 10.8 14.8 7.8 12 3z"/><path d="M9.4 15.2a2.8 2.8 0 0 0 2.4 2.6"/>',
    "altar": '<path d="M4.5 14h15M6.5 14v6h11v-6M5 20.5h14"/><path d="M12 11.4c-2.2-1.4-2.4-4-.2-7.4 2.4 3 2.5 5.6.2 7.4z"/>',
    "cypress": '<path d="M12 21v-3M12 18c-3 0-4-3-4-6 0-4 2-8 4-9 2 1 4 5 4 9 0 3-1 6-4 6z"/>',
    "temple": '<path d="M3 9 12 4l9 5z"/><path d="M4 9h16M6.2 10.5v7.5M10 10.5v7.5M14 10.5v7.5M17.8 10.5v7.5M3.5 18.5h17M2.5 21h19"/>',
    "pause": '<path d="M9 6v12M15 6v12"/>',
    "play1": '<path class="f" d="M8 5.5 18.5 12 8 18.5z"/>',
    "play2": '<path class="f" d="M3.5 6 12 12l-8.5 6zM12 6l8.5 6-8.5 6z"/>',
    "play3": '<path class="f" d="M1.5 7 8 12l-6.5 5zM8.5 7 15 12l-6.5 5zM15.5 7 22 12l-6.5 5z"/>',
    "eye": '<path d="M2 12s3.8-6.5 10-6.5S22 12 22 12s-3.8 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/>',
    "scroll": '<path d="M7 4h11a2 2 0 0 1 0 4h-1v10a2 2 0 0 1-2 2H6a2 2 0 0 1 0-4h1z"/><path d="M7 16v-12M10 9h4M10 12h4"/>',
    "menu": '<path d="M4 7h16M4 12h16M4 17h16"/>',
    "check": '<path d="m4.5 12.5 4.5 4.5L19.5 6.5"/>',
    "open": '<circle cx="12" cy="12" r="7"/>',
    "laurel": '<path d="M12 20c-4.5-1-7.5-5-7.5-10M12 20c4.5-1 7.5-5 7.5-10"/>'
              '<path d="M5.2 13.4c-1.8-.4-2.6-1.6-2.6-3 1.6.2 2.6 1.3 2.6 3zM6.8 16.6c-1.8.2-3-.6-3.4-1.9 1.6-.3 2.8.4 3.4 1.9z'
              'M18.8 13.4c1.8-.4 2.6-1.6 2.6-3-1.6.2-2.6 1.3-2.6 3zM17.2 16.6c1.8.2 3-.6 3.4-1.9-1.6-.3-2.8.4-3.4 1.9z"/>',
    "fire": '<path d="M12 21c-3.6 0-6-2.4-6-5.6 0-3.2 2.4-5 3.4-8 1.6 1.4 2 3 1.8 4.6C13 10.6 13.6 7 13 3c3.6 2.4 5 6.6 5 10.6 0 4-2.4 7.4-6 7.4z"/>',
}


def icons():
    d = os.path.join(OUT, "icons")
    os.makedirs(d, exist_ok=True)
    for name, body in ICONS.items():
        body = body.replace('class="f"', 'fill="#fff" stroke="none"')
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" '
               'stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</svg>\n' % body)
        with open(os.path.join(d, name + ".svg"), "w") as f:
            f.write(svg)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    panel()
    button("normal", "#f7f2e8", "#ddd3bf", STONE_LINE, "#ffffff")
    button("hover", "#fcf8f0", "#e8dfcc", TERRA, "#ffffff")
    button("pressed", "#b6553a", "#8f3a22", "#6e2a17", "#c9775e")
    button("disabled", "#eee8dc", "#e2dacb", INNER_LINE, None)
    topbar()
    frieze()
    icons()
    print("interface : %s" % OUT)
