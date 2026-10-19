"""Desenha a porta biométrica corporativa (placeholder no estilo do jogo).
Gera assets/objects/door/door_sheet.png: 7 quadros de 56x144, lado a lado.
  0-1: trancada (luz vermelha, piscando)   2-6: abrindo (sobe) com luz verde
Uso: python tools/gen_door_art.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 56, 144
OUT = (8, 8, 10, 255)
FRAME_D = (34, 34, 38, 255)
FRAME_M = (52, 52, 56, 255)
FRAME_L = (78, 76, 78, 255)
DOOR_D = (40, 42, 48, 255)
DOOR_M = (58, 60, 66, 255)
DOOR_L = (90, 92, 98, 255)
STRIPE = (150, 120, 40, 255)
STRIPE_D = (40, 34, 20, 255)
RED = (230, 50, 44, 255)
RED_D = (100, 20, 20, 255)
GREEN = (80, 240, 110, 255)
RUST = (100, 56, 34, 255)


def frame(light, slide):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    # moldura (8 px) em volta da abertura de 40x136
    for y in range(H):
        for x in range(W):
            inside = 8 <= x < W - 8 and 8 <= y < H
            if inside:
                continue
            edge = x in (0, W - 1) or y == 0 or x in (7, W - 8) or y == 7
            px[x, y] = OUT if edge else (FRAME_L if y < 4 or x < 3 else FRAME_M if x < W - 3 else FRAME_D)
    # rebites
    for y in range(14, H, 22):
        px[3, y] = FRAME_L
        px[W - 4, y] = FRAME_D
    # luz de status no topo da moldura
    for x in range(24, 32):
        for y in range(2, 5):
            px[x, y] = light
    # folha da porta (sobe "slide" px)
    for y in range(8, H):
        sy = y + slide
        if sy >= H:
            continue
        for x in range(8, W - 8):
            dy = sy - 8
            if x in (8, W - 9) or dy in (0,):
                c = OUT
            elif dy % 34 == 33:
                c = DOOR_D
            elif 52 <= dy <= 58:
                c = STRIPE if (x + dy) % 8 < 4 else STRIPE_D
            elif x < 12:
                c = DOOR_L
            elif x > W - 14:
                c = DOOR_D
            else:
                c = DOOR_M
            if (x * 7 + dy * 3) % 61 == 0:
                c = RUST
            px[x, y] = c
    # sombra da abertura atrás quando aberta
    for y in range(8, H):
        for x in range(8, W - 8):
            if px[x, y][3] == 0:
                px[x, y] = (14, 12, 16, 255)
    return img


if __name__ == "__main__":
    frames = [frame(RED, 0), frame(RED_D, 0)] + [frame(GREEN, s) for s in (0, 34, 68, 102, 136)]
    sheet = Image.new("RGBA", (W * len(frames), H))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * W, 0))
    out = os.path.join(ROOT, "assets", "objects", "door")
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, "door_sheet.png"))
    print("ok", sheet.size)
