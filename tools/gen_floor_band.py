"""Gera a faixa de "chão em profundidade" das favelas (falso 3D, sem colisão).

A colisão continua na linha da superfície; esta faixa é desenhada por cima da
borda do tileset, de BACK px acima da superfície até FRONT px abaixo, para os
pés dos personagens e as bases dos props (desenhados em 3/4) pisarem num chão.

Uso: python tools/gen_floor_band.py  ->  assets/tilesets/slums/floor_band.png
"""
import random
from pathlib import Path

from PIL import Image

W = 256          # largura do tile (repete na horizontal)
BACK = 22        # px acima da superfície (fundo da calçada)
FRONT = 8        # px abaixo da superfície (beirada frontal)
H = BACK + FRONT

OUT = Path(__file__).resolve().parent.parent / "assets/tilesets/slums/floor_band.png"

random.seed(7)

# Paleta tirada do tileset do chão (pedra marrom-acinzentada, grime, neon rosa).
BACK_COL = (34, 30, 34)
MID_COL = (58, 51, 50)
FRONT_COL = (74, 65, 60)
SEAM = (30, 26, 28)
CRACK = (26, 22, 24)
GRIME = (48, 52, 40)
LIP_DARK = (24, 20, 24)
LIP_LIGHT = (96, 84, 76)
PINK = (236, 72, 196)
CYAN = (60, 220, 235)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def main() -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    # Gradiente de profundidade (fundo escuro -> frente iluminada), com ruído.
    lip = H - 4
    for y in range(lip):
        t = y / (lip - 1)
        base = lerp(BACK_COL, MID_COL, min(t * 1.4, 1.0)) if t < 0.7 else lerp(MID_COL, FRONT_COL, (t - 0.7) / 0.3)
        for x in range(W):
            n = random.randint(-4, 4)
            px[x, y] = (*(max(0, min(255, c + n)) for c in base), 255)

    # Juntas das placas em perspectiva: horizontais e "raios" para o fundo.
    for y in (6, 13):
        for x in range(W):
            if random.random() > 0.15:
                px[x, y] = (*SEAM, 255)
    for x0 in range(0, W, 64):
        for y in range(lip):
            # a junta inclina levemente para o centro conforme vai para o fundo
            x = (x0 + int((lip - y) * 0.35)) % W
            px[x, y] = (*SEAM, 255)

    # Rachaduras.
    for _ in range(9):
        x = random.randrange(W)
        y = random.randrange(2, lip - 2)
        for _ in range(random.randint(4, 12)):
            px[x % W, y] = (*CRACK, 255)
            x += random.choice((1, 1, 2))
            y = max(1, min(lip - 2, y + random.choice((-1, 0, 0, 1))))

    # Manchas de limo/grime.
    for _ in range(14):
        cx, cy = random.randrange(W), random.randrange(0, lip)
        for _ in range(random.randint(6, 18)):
            x = (cx + random.randint(-4, 4)) % W
            y = max(0, min(lip - 1, cy + random.randint(-1, 1)))
            r, g, b, _a = px[x, y]
            px[x, y] = (*lerp((r, g, b), GRIME, 0.5), 255)

    # Poças rasas refletindo neon (achatadas pela perspectiva).
    for (cx, cy, rw, col) in ((40, 15, 14, PINK), (150, 18, 18, CYAN), (215, 10, 9, PINK)):
        for y in range(cy - 2, cy + 3):
            half = int(rw * (1 - abs(y - cy) / 3.0))
            for x in range(cx - half, cx + half + 1):
                r, g, b, _a = px[x % W, y]
                dark = lerp((r, g, b), (14, 14, 22), 0.55)
                k = 0.28 if (x + y) % 3 else 0.45
                px[x % W, y] = (*lerp(dark, col, k * (1 - abs(x - cx) / (half + 1))), 255)

    # Beirada frontal: luz no topo, sombra embaixo, pontinhos de neon como no tileset.
    for x in range(W):
        px[x, lip] = (*LIP_LIGHT, 255)
        px[x, lip + 1] = (*lerp(LIP_LIGHT, FRONT_COL, 0.5), 255)
        px[x, lip + 2] = (*LIP_DARK, 255)
        px[x, lip + 3] = (*LIP_DARK, 200)
    for x in range(3, W, 9):
        if random.random() < 0.7:
            px[x, lip + 1] = (*PINK, 255)
            px[(x + 1) % W, lip + 1] = (*PINK, 255)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print("salvo", OUT, img.size)


if __name__ == "__main__":
    main()
