#!/usr/bin/env python3
"""Arte da Fase 4 (Núcleo Quântico) a partir das imagens do PixelLab guardadas
em tools/art_src/core/ (originais intactos; este script só recorta e ajusta):

- background.png  -> assets/backgrounds/core/bg_core[_seamless].png (vazio com
                     geometrias; escurecido)
- dome.png        -> assets/backgrounds/core/bg_dome.png: o túnel de anéis
                     espelhado na metade esquerda, para o "olho" ficar no
                     centro (atrás do núcleo); escurecido
- ending.png      -> assets/backgrounds/core/ending.png (tela de encerramento)
- portrait_*.png  -> assets/ui/portraits/<nome>.png (retratos da caixa de
                     diálogo; o da Axioma perde um "texto" que a IA desenhou
                     no canto)

O tileset é feito por tools/gen_rnd_tiles.py com o tema "core".

Uso (na raiz do projeto):  python3 tools/gen_core_art.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools/art_src/core")
## Coluna do centro do túnel no dome.png (medida: menor brilho médio).
DOME_CENTER_X = 447


def out(rel: str) -> str:
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def _darken(im: np.ndarray, k: float, sat: float = 0.85) -> Image.Image:
    grey = im.mean(axis=2, keepdims=True)
    im = grey + (im - grey) * sat
    im = im * k + np.array([2, 3, 6])
    return Image.fromarray(np.clip(im, 0, 255).astype(np.uint8), "RGB")


def background() -> None:
    im = np.array(Image.open(os.path.join(SRC, "background.png")).convert("RGB")).astype(float)
    img = _darken(im, 0.32)
    img.save(out("assets/backgrounds/core/bg_core.png"))
    seam = Image.new("RGB", (img.width * 2, img.height))
    seam.paste(img, (0, 0))
    seam.paste(img.transpose(Image.FLIP_LEFT_RIGHT), (img.width, 0))
    seam.save(out("assets/backgrounds/core/bg_core_seamless.png"))
    print("fundo", seam.size)


def dome() -> None:
    im = Image.open(os.path.join(SRC, "dome.png")).convert("RGB")
    left = im.crop((0, 0, DOME_CENTER_X, im.height))
    sym = Image.new("RGB", (DOME_CENTER_X * 2, im.height))
    sym.paste(left, (0, 0))
    sym.paste(left.transpose(Image.FLIP_LEFT_RIGHT), (DOME_CENTER_X, 0))
    img = _darken(np.array(sym).astype(float), 0.3, 0.85)
    img.save(out("assets/backgrounds/core/bg_dome.png"))
    print("domo", img.size)


def ending() -> None:
    im = Image.open(os.path.join(SRC, "ending.png")).convert("RGB")
    im.save(out("assets/backgrounds/core/ending.png"))
    print("final", im.size)


def portraits() -> None:
    for name in ["eduardo", "sine", "axioma", "vance"]:
        im = Image.open(os.path.join(SRC, "portrait_%s.png" % name)).convert("RGBA")
        if name == "axioma":
            a = np.array(im)
            a[0:15, 0:23, :3] = a[20:30, 2:8, :3].reshape(-1, 3).mean(axis=0).astype(np.uint8)
            im = Image.fromarray(a, "RGBA")
        im.save(out("assets/ui/portraits/%s.png" % name))
        print("retrato", name, im.size)


if __name__ == "__main__":
    background()
    dome()
    ending()
    portraits()
