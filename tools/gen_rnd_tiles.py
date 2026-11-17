#!/usr/bin/env python3
"""Gera o tileset do Setor de P&D (Fase 3) com o mesmo FORMATO do tileset das
favelas (15 tiles de canto + variantes, mesma colisão e mesmo terreno), como
tools/gen_industrial_tiles.py, mas com placas desenhadas aqui: painéis lisos
cinza-azulados com bisel, emendas finas e detalhes ciano. O P&D é "limpo e
minimalista" (GDD §6); uma textura gerada por IA saía suja demais.

- Tons médios (não branco): o Eduardo, escuro, e os cones de visão continuam
  legíveis contra o cenário.
- Contorno escuro de 1 px onde o tile encontra o vazio.
- Topo andável: friso claro + filete de luz ciano.

Uso (na raiz do projeto):  python3 tools/gen_rnd_tiles.py
Saída: tools/art_src/rnd/plates.png (textura) e assets/tilesets/rnd/rnd_ground.png
(+ .tres copiado do das favelas, só com a textura trocada).
"""
import os
import random
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_ATLAS = os.path.join(ROOT, "assets/tilesets/slums/slums_ground.png")
SRC_TRES = os.path.join(ROOT, "assets/tilesets/slums/slums_ground.tres")
ART_SRC = os.path.join(ROOT, "tools/art_src/rnd")
OUT_DIR = os.path.join(ROOT, "assets/tilesets/rnd")
NAME = "rnd_ground"
T = 32

OUTLINE = (12, 10, 10)
TRIM = (206, 220, 230)
CYAN = (0, 214, 236)
CYAN_DIM = (40, 120, 140)
DEEP = 0.7
DEEP_FROM = 7

PANEL = (126, 140, 156)
PANEL_HI = (156, 170, 186)
PANEL_LO = (96, 108, 124)
SEAM = (58, 66, 80)


def plate(kind: int, rng: random.Random) -> Image.Image:
    """Uma placa 32x32: painel com bisel (luz em cima/esquerda) e um detalhe."""
    img = Image.new("RGB", (T, T), SEAM)
    d = ImageDraw.Draw(img)
    d.rectangle([1, 1, T - 2, T - 2], fill=PANEL)
    d.line([1, 1, T - 2, 1], fill=PANEL_HI)
    d.line([1, 1, 1, T - 2], fill=PANEL_HI)
    d.line([1, T - 2, T - 2, T - 2], fill=PANEL_LO)
    d.line([T - 2, 1, T - 2, T - 2], fill=PANEL_LO)
    # leve variação de tom entre placas
    shift = rng.randint(-6, 6)
    arr = np.array(img).astype(int)
    arr[2:T - 2, 2:T - 2] += shift
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if kind == 1:      # grade de ventilação
        for y in range(10, 22, 3):
            d.line([9, y, 22, y], fill=PANEL_LO)
    elif kind == 2:    # luz indicadora ciano
        d.rectangle([24, 5, 26, 6], fill=CYAN)
    elif kind == 3:    # sulco horizontal
        d.line([3, 16, T - 4, 16], fill=PANEL_LO)
        d.line([3, 17, T - 4, 17], fill=PANEL_HI)
    elif kind == 4:    # parafusos nos cantos
        for x, y in ((4, 4), (27, 4), (4, 27), (27, 27)):
            d.point((x, y), fill=PANEL_LO)
    elif kind == 5:    # filete ciano apagado
        d.line([6, 26, 25, 26], fill=CYAN_DIM)
    return img


def make_plates() -> str:
    rng = random.Random(3)
    tex = Image.new("RGB", (T * 4, T * 4))
    kinds = [0, 1, 0, 4, 2, 0, 3, 0, 0, 5, 4, 0, 3, 0, 1, 0]
    for i, k in enumerate(kinds):
        tex.paste(plate(k, rng), ((i % 4) * T, (i // 4) * T))
    os.makedirs(ART_SRC, exist_ok=True)
    path = os.path.join(ART_SRC, "plates.png")
    tex.save(path)
    return path


def dist_to_empty(alpha: np.ndarray) -> np.ndarray:
    h, w = alpha.shape
    d = np.full((h, w), 999, dtype=int)
    q = deque()
    for y in range(h):
        for x in range(w):
            if alpha[y, x] == 0:
                d[y, x] = 0
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and d[ny, nx] > d[y, x] + 1:
                d[ny, nx] = d[y, x] + 1
                q.append((ny, nx))
    return d


def empty_above(alpha: np.ndarray, y: int, x: int, reach: int) -> int:
    for k in range(1, reach + 1):
        if y - k < 0:
            return 0
        if alpha[y - k, x] == 0:
            return k
    return 0


def build(texture_path: str) -> None:
    atlas = np.array(Image.open(SRC_ATLAS).convert("RGBA"))
    tex = np.array(Image.open(texture_path).convert("RGB")).astype(float)
    plates = [tex[r * T:(r + 1) * T, c * T:(c + 1) * T] for r in range(4) for c in range(4)]
    out = np.zeros_like(atlas)
    rows, cols = atlas.shape[0] // T, atlas.shape[1] // T
    for cy in range(rows):
        for cx in range(cols):
            cell = atlas[cy * T:(cy + 1) * T, cx * T:(cx + 1) * T]
            alpha = cell[:, :, 3]
            if alpha.max() == 0:
                continue
            pl = plates[(cy * cols + cx) * 5 % 16]
            d = dist_to_empty(alpha)
            res = np.zeros_like(cell)
            for y in range(T):
                for x in range(T):
                    if alpha[y, x] == 0:
                        continue
                    up = empty_above(alpha, y, x, 5)
                    if d[y, x] == 1:
                        rgb = OUTLINE
                    elif up == 2:
                        rgb = TRIM
                    elif up == 3:
                        rgb = CYAN
                    elif up == 4:
                        rgb = CYAN_DIM
                    elif d[y, x] == 2:
                        rgb = tuple(int(v * 0.6) for v in pl[y, x])
                    else:
                        k = 1.0 if d[y, x] < DEEP_FROM else DEEP
                        rgb = tuple(int(v * k) for v in pl[y, x])
                    res[y, x] = (*rgb, 255)
            out[cy * T:(cy + 1) * T, cx * T:(cx + 1) * T] = res
    os.makedirs(OUT_DIR, exist_ok=True)
    img = Image.fromarray(out, "RGBA")
    img.save(os.path.join(OUT_DIR, NAME + ".png"))
    img.resize((img.width * 4, img.height * 4), Image.NEAREST).save(
        os.path.join(ART_SRC, NAME + "_preview_x4.png"))
    tres = open(SRC_TRES, encoding="utf-8").read()
    tres = tres.replace("res://assets/tilesets/slums/slums_ground.png",
                        "res://assets/tilesets/rnd/%s.png" % NAME)
    open(os.path.join(OUT_DIR, NAME + ".tres"), "w", encoding="utf-8").write(tres)
    print("ok:", os.path.join(OUT_DIR, NAME + ".png"), img.size)


if __name__ == "__main__":
    build(make_plates())
