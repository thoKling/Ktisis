"""Génère les sprites : python render.py [noms...] (avec le module bpy, voir README)."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit  # noqa: E402
from buildings import BUILDINGS, PROPS, WALKERS  # noqa: E402
import houses  # noqa: E402,F401  (enregistre les maisons)
import details  # noqa: E402,F401  (seconde passe de détails)
import acropolis  # noqa: E402,F401  (monuments de la colline sacrée)
import storage  # noqa: E402  (grenier et entrepôt à cases, et leurs cases pleines)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def main(names):
    every = {name: ("buildings",) + v for name, v in BUILDINGS.items()}
    every.update({name: ("props",) + v for name, v in PROPS.items()})
    every.update({name: ("walkers",) + v for name, v in WALKERS.items()})
    every.update({name: ("goods", fn, 1) for name, fn in storage.goods_jobs()})
    todo = names or sorted(every)
    for name in todo:
        folder, fn, size = every[name]
        kit.reset()
        fn()
        out = os.path.join(ROOT, "assets", folder, name + ".png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        kit.render(out, size)
        print("ok", name)


if __name__ == "__main__":
    main(sys.argv[1:])
