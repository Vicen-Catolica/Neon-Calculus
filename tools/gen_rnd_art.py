#!/usr/bin/env python3
"""Arte da Fase 3 (Setor de P&D) a partir das imagens do PixelLab guardadas em
tools/art_src/rnd/ (originais intactos; este script só recorta e ajusta):

- background.png    -> assets/backgrounds/rnd/bg_rnd[_seamless].png (escurecido)
- props_sheet.png   -> assets/props/rnd/<nome>.png (9 objetos, recortados por
                       componente conexo e ordenados em grade 3x3)
- vance.png         -> assets/props/rnd/vance.png (Dr. Vance na cela)
- exec_elevator.png -> assets/props/rnd/exec_elevator.png
- ciborgue          -> assets/characters/cyborg/<anim>/frame_N.png: recolor dos
                       frames do guarda v2 (armadura branco-acinzentada, juntas
                       escuras, visor e detalhes no vermelho da Axioma) +
                       scenes/enemies/cyborg_frames.tres

O tileset é feito por tools/gen_rnd_tiles.py; a luz do teto, por
tools/gen_rnd_placeholders.py.

Uso (na raiz do projeto):  python3 tools/gen_rnd_art.py
"""
import os
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools/art_src/rnd")


def out(rel: str) -> str:
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def background() -> None:
    im = np.array(Image.open(os.path.join(SRC, "background.png")).convert("RGB")).astype(float)
    grey = im.mean(axis=2, keepdims=True)
    im = grey + (im - grey) * 0.8
    im = im * 0.34 + np.array([4, 6, 10])   # fundo atrás do jogador: escuro e frio
    img = Image.fromarray(np.clip(im, 0, 255).astype(np.uint8), "RGB")
    img.save(out("assets/backgrounds/rnd/bg_rnd.png"))
    seam = Image.new("RGB", (img.width * 2, img.height))
    seam.paste(img, (0, 0))
    seam.paste(img.transpose(Image.FLIP_LEFT_RIGHT), (img.width, 0))
    seam.save(out("assets/backgrounds/rnd/bg_rnd_seamless.png"))
    print("fundo", img.size, seam.size)


PROPS = [
    ["reception_counter", "cubicle", "plant"],
    ["filing_cabinet", "lab_bench", "sample_tank"],
    ["water_cooler", "server_white", "monitor_stand"],
]


def _components(alpha: np.ndarray, min_px: int = 60) -> list:
    """Caixas (x0, y0, x1, y1) dos componentes conexos (8-vizinhos) opacos."""
    h, w = alpha.shape
    seen = np.zeros_like(alpha, dtype=bool)
    boxes = []
    for y in range(h):
        for x in range(w):
            if alpha[y, x] == 0 or seen[y, x]:
                continue
            q = deque([(y, x)])
            seen[y, x] = True
            n, x0, y0, x1, y1 = 0, x, y, x, y
            while q:
                cy, cx = q.popleft()
                n += 1
                x0, y0, x1, y1 = min(x0, cx), min(y0, cy), max(x1, cx), max(y1, cy)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and alpha[ny, nx] > 0 and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((ny, nx))
            if n >= min_px:
                boxes.append((x0, y0, x1 + 1, y1 + 1, n))
    return boxes


def props() -> None:
    sheet = Image.open(os.path.join(SRC, "props_sheet.png")).convert("RGBA")
    alpha = np.array(sheet)[:, :, 3]
    boxes = sorted(_components(alpha), key=lambda b: -b[4])[:9]
    cw, ch = sheet.width / 3, sheet.height / 3
    for r, row in enumerate(PROPS):
        for c, name in enumerate(row):
            cx, cy = (c + 0.5) * cw, (r + 0.5) * ch
            b = min(boxes, key=lambda b: ((b[0] + b[2]) / 2 - cx) ** 2 + ((b[1] + b[3]) / 2 - cy) ** 2)
            img = sheet.crop(b[:4])
            img.save(out("assets/props/rnd/%s.png" % name))
            print("prop", name, img.size)


def _cropped(name: str) -> Image.Image:
    im = Image.open(os.path.join(SRC, name)).convert("RGBA")
    return im.crop(im.getbbox())


def vance() -> None:
    im = _cropped("vance.png")
    im.save(out("assets/props/rnd/vance.png"))
    print("vance", im.size)


def elevator() -> None:
    im = _cropped("exec_elevator.png")
    im.save(out("assets/props/rnd/exec_elevator.png"))
    print("elevador", im.size)


# --- Ciborgue (recolor do guarda v2) -----------------------------------------

GUARD_DIR = os.path.join(ROOT, "assets/characters/guard/v2")
CYBORG_DIR = "assets/characters/cyborg"
DARK = np.array([50, 56, 70], dtype=float)
LIGHT = np.array([232, 240, 248], dtype=float)
RED = np.array([255, 40, 60], dtype=float)


def _recolor(img: Image.Image) -> Image.Image:
    a = np.array(img.convert("RGBA")).astype(float)
    rgb, al = a[:, :, :3], a[:, :, 3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    lum = rgb.mean(axis=2) / 255.0
    outline = lum < 0.06
    accent = (r > g + 50) & (r > b + 50)   # laranja/vermelho do guarda
    t = np.clip((lum - 0.07) / (0.6 - 0.07), 0.0, 1.0) ** 0.8
    armor = DARK + (LIGHT - DARK) * t[:, :, None]
    lit = np.clip(lum / 0.8, 0.45, 1.0)[:, :, None]
    new = np.where(accent[:, :, None], RED * lit, armor)
    new = np.where(outline[:, :, None], rgb, new)
    out_a = np.dstack([np.clip(new, 0, 255), al]).astype(np.uint8)
    out_a[al == 0] = 0
    return Image.fromarray(out_a, "RGBA")


def cyborg() -> None:
    n = 0
    for anim in sorted(os.listdir(GUARD_DIR)):
        src = os.path.join(GUARD_DIR, anim)
        if not os.path.isdir(src):
            continue
        for f in sorted(os.listdir(src)):
            if not f.endswith(".png"):
                continue
            _recolor(Image.open(os.path.join(src, f))).save(out("%s/%s/%s" % (CYBORG_DIR, anim, f)))
            n += 1
    tres = open(os.path.join(ROOT, "scenes/enemies/guard_v2_frames.tres"), encoding="utf-8").read()
    tres = tres.replace("res://assets/characters/guard/v2/", "res://%s/" % CYBORG_DIR)
    open(out("scenes/enemies/cyborg_frames.tres"), "w", encoding="utf-8").write(tres)
    print("ciborgue", n, "frames")


if __name__ == "__main__":
    background()
    props()
    vance()
    elevator()
    cyborg()
