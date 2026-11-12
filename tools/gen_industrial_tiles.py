"""Gera o tileset do Setor Industrial reaproveitando o FORMATO do tileset das
favelas (15 tiles de canto + variantes, mesma colisão e mesmo terreno) e
trocando o "recheio" por chapas de aço rebitadas (textura gerada no PixelLab).

- Contorno escuro de 1 px onde o tile encontra o vazio.
- Topo andável: friso de aço claro + faixa de perigo amarela/preta.
- Laterais e base: borda sombreada.
- Cada célula do atlas usa uma das 16 placas da textura (variação).

Uso (na raiz do projeto):
  python3 tools/gen_industrial_tiles.py <textura_128x128.png>
Saída: assets/tilesets/industrial/industrial_ground.png (+ .tres copiado do das
favelas, só com a textura trocada).
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_ATLAS = os.path.join(ROOT, "assets/tilesets/slums/slums_ground.png")
SRC_TRES = os.path.join(ROOT, "assets/tilesets/slums/slums_ground.tres")
OUT_DIR = os.path.join(ROOT, "assets/tilesets/industrial")
NAME = "industrial_ground"
T = 32

OUTLINE = (12, 10, 10)
EDGE_LIGHT = (128, 120, 110)
HAZARD_Y = (196, 152, 38)
HAZARD_K = (24, 20, 16)
DARKEN = 0.72
## Miolo do bloco (longe de qualquer borda) bem mais escuro: só as chapas da
## superfície ficam com cor cheia, como o concreto da favela.
DEEP = 0.42
DEEP_FROM = 7


def dist_to_empty(alpha: np.ndarray) -> np.ndarray:
    """Distância (4-vizinhos) de cada pixel opaco ao pixel transparente mais
    próximo DENTRO da célula. As bordas da célula não contam como vazio: o
    terreno continua no tile vizinho."""
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
    """Quantos px acima está o vazio (0 = não há vazio até `reach`)."""
    for k in range(1, reach + 1):
        if y - k < 0:
            return 0
        if alpha[y - k, x] == 0:
            return k
    return 0


def build(texture_path: str) -> None:
    atlas = np.array(Image.open(SRC_ATLAS).convert("RGBA"))
    tex = np.array(Image.open(texture_path).convert("RGB")).astype(float) * DARKEN
    plates = [tex[r * T:(r + 1) * T, c * T:(c + 1) * T] for r in range(4) for c in range(4)]
    out = np.zeros_like(atlas)
    rows, cols = atlas.shape[0] // T, atlas.shape[1] // T
    for cy in range(rows):
        for cx in range(cols):
            cell = atlas[cy * T:(cy + 1) * T, cx * T:(cx + 1) * T]
            alpha = cell[:, :, 3]
            if alpha.max() == 0:
                continue
            plate = plates[(cy * cols + cx) * 5 % 16]
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
                        rgb = EDGE_LIGHT
                    elif up in (3, 4):
                        # faixa diagonal de perigo, contínua entre tiles vizinhos
                        rgb = HAZARD_Y if ((x + cx * T + y) // 4) % 2 == 0 else HAZARD_K
                    elif d[y, x] == 2:
                        rgb = tuple(int(v * 0.55) for v in plate[y, x])
                    else:
                        k = 1.0 if d[y, x] < DEEP_FROM else DEEP
                        rgb = tuple(int(v * k) for v in plate[y, x])
                    res[y, x] = (*rgb, 255)
            out[cy * T:(cy + 1) * T, cx * T:(cx + 1) * T] = res
    os.makedirs(OUT_DIR, exist_ok=True)
    img = Image.fromarray(out, "RGBA")
    img.save(os.path.join(OUT_DIR, NAME + ".png"))
    img.resize((img.width * 4, img.height * 4), Image.NEAREST).save(
        os.path.join(os.path.dirname(texture_path), NAME + "_preview_x4.png"))
    tres = open(SRC_TRES, encoding="utf-8").read()
    tres = tres.replace("res://assets/tilesets/slums/slums_ground.png",
                        "res://assets/tilesets/industrial/%s.png" % NAME)
    open(os.path.join(OUT_DIR, NAME + ".tres"), "w", encoding="utf-8").write(tres)
    print("ok:", os.path.join(OUT_DIR, NAME + ".png"), img.size)


if __name__ == "__main__":
    build(sys.argv[1])
