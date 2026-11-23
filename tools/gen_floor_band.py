"""Gera a faixa de "chão em profundidade" das favelas (falso 3D, sem colisão).

A colisão continua na linha da superfície; esta faixa é desenhada por cima da
borda do tileset, de BACK px acima da superfície até FRONT px abaixo, para os
pés dos personagens e as bases dos props (desenhados em 3/4) pisarem num chão.

Também gera catwalk_band.png: a grade de metal das passarelas vista de cima
(CW_BACK px acima da superfície, CW_FRONT abaixo), para o terminal e o
jogador pisarem "dentro" da passarela.

Uso: python tools/gen_floor_band.py  ->  assets/tilesets/slums/floor_band.png
     python tools/gen_floor_band.py industrial  ->  assets/tilesets/industrial/floor_band.png
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


CW_BACK = 14
CW_FRONT = 3
CW_OUT = OUT.parent / "catwalk_band.png"


def catwalk() -> None:
    w, h = 64, CW_BACK + CW_FRONT
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    frame = (70, 74, 80)
    frame_hi = (104, 108, 112)
    bar = (52, 55, 60)
    hole = (14, 14, 20)
    for y in range(h - 2):
        t = y / (h - 3)
        for x in range(w):
            # grade: barras transversais (em perspectiva) e longarinas
            is_bar = (x % 4 == 0) or (y % 4 == 0)
            c = bar if is_bar else hole
            c = lerp(c, (0, 0, 0), 0.45 * (1 - t))  # fundo mais escuro
            px[x, y] = (*c, 255)
    for x in range(w):
        px[x, 0] = (*lerp(frame, (0, 0, 0), 0.4), 255)
        px[x, h - 3] = (*frame_hi, 255)
        px[x, h - 2] = (*frame, 255)
        px[x, h - 1] = (*LIP_DARK, 255)
    for x in range(5, w, 16):  # ferrugem
        for y in range(h - 3, h):
            px[x, y] = (112, 64, 36, 255)
    img.save(CW_OUT)
    print("salvo", CW_OUT, img.size)


IND_OUT = OUT.parent.parent / "industrial/floor_band.png"


def industrial() -> None:
    """Piso do Setor Industrial em profundidade: chapas de aço com relevo de
    losango, rebites, ferrugem e óleo, e a faixa de perigo amarela e preta na
    beirada (a mesma do tileset). Mesmas medidas da faixa das favelas."""
    rnd = random.Random(11)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    back, mid, front = (30, 30, 32), (58, 56, 54), (82, 78, 72)
    seam, tread_hi, tread_lo = (20, 20, 22), (100, 96, 88), (44, 42, 40)
    rust, oil = (108, 58, 30), (16, 14, 14)
    hazard_y, hazard_k = (196, 152, 38), (24, 20, 16)
    lip = H - 4
    for y in range(lip):
        t = y / (lip - 1)
        base = lerp(back, mid, min(t * 1.4, 1.0)) if t < 0.7 else lerp(mid, front, (t - 0.7) / 0.3)
        for x in range(W):
            n = rnd.randint(-3, 3)
            c = tuple(max(0, min(255, v + n)) for v in base)
            # relevo de losango (chapa antiderrapante), achatado pela perspectiva
            if (x + 2 * y) % 8 == 0 and y % 3 == 1:
                c = lerp(c, tread_hi, 0.35 * t + 0.1)
            elif (x - 2 * y) % 8 == 0 and y % 3 == 2:
                c = lerp(c, tread_lo, 0.4)
            px[x, y] = (*c, 255)
    # juntas entre chapas: horizontais e "raios" para o fundo
    for y in (7, 14):
        for x in range(W):
            px[x, y] = (*seam, 255)
    for x0 in range(0, W, 48):
        for y in range(lip):
            x = (x0 + int((lip - y) * 0.35)) % W
            px[x, y] = (*seam, 255)
            # rebites ao lado da junta
            if y in (4, 11, 18):
                px[(x + 3) % W, y] = (*tread_hi, 255)
    # ferrugem e manchas de óleo (o óleo reflete o laranja das lâmpadas)
    for _ in range(10):
        cx, cy = rnd.randrange(W), rnd.randrange(1, lip - 1)
        for _ in range(rnd.randint(6, 16)):
            x = (cx + rnd.randint(-5, 5)) % W
            y = max(0, min(lip - 1, cy + rnd.randint(-1, 1)))
            r, g, b, _a = px[x, y]
            px[x, y] = (*lerp((r, g, b), rust, 0.45), 255)
    for (cx, cy, rw) in ((60, 16, 16), (180, 12, 11)):
        for y in range(cy - 2, cy + 3):
            half = int(rw * (1 - abs(y - cy) / 3.0))
            for x in range(cx - half, cx + half + 1):
                k = 0.25 * (1 - abs(x - cx) / (half + 1))
                px[x % W, y] = (*lerp(oil, (255, 120, 40), k), 255)
    # beirada: friso claro + faixa de perigo diagonal
    for x in range(W):
        px[x, lip] = (*tread_hi, 255)
        for k, y in enumerate((lip + 1, lip + 2)):
            px[x, y] = (*(hazard_y if ((x + y) // 4) % 2 == 0 else hazard_k), 255)
        px[x, lip + 3] = (12, 10, 10, 255)
    IND_OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(IND_OUT)
    print("salvo", IND_OUT, img.size)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "industrial":
        industrial()
    else:
        main()
        catwalk()
