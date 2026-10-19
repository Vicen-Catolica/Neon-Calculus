"""Prepara as fachadas das favelas geradas no PixelLab para o jogo.

Lê  nobg/slums - facades/raw/*.png  (saída crua do PixelLab, não editar)
Grava nobg/slums - facades/<nome>.png  e  assets/props/slums/facades/<nome>.png

- storefront_*: térreo com loja (recorte rente ao desenho).
- storey_*: um andar de casa, 192x128 opaco, empilhável (o código põe uma laje
  de concreto entre os andares para esconder a emenda).
- water_tank / laundry_line / antenna: props de laje (remove o prédio que veio
  junto no fundo da geração e completa os postes).
- slab_strip: faixa de laje entre andares, gerada aqui.

Uso: python tools/gen_facades.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(r"C:/Users/vicen/OneDrive/Documentos/Krita/Neon Calculus/nobg/slums - facades")
RAW = ART / "raw"
PROJ = Path(__file__).resolve().parent.parent / "assets/props/slums/facades"

OUT_COL = (12, 10, 10, 255)
RUST = [(82, 46, 30, 255), (112, 64, 36, 255), (146, 88, 48, 255)]


def save(img: Image.Image, name: str) -> None:
    for d in (ART, PROJ):
        d.mkdir(parents=True, exist_ok=True)
        img.save(d / f"{name}.png")
    print("salvo", name, img.size)


def trim(img: Image.Image) -> Image.Image:
    return img.crop(img.getbbox())


def pole(img: Image.Image, x: int, y0: int, y1: int, w: int = 3) -> None:
    px = img.load()
    for y in range(y0, y1):
        px[x - 1, y] = OUT_COL
        px[x + w, y] = OUT_COL
        for k in range(w):
            px[x + k, y] = RUST[1] if k == 0 else (RUST[0] if (y // 5 + k) % 3 else RUST[2])


def main() -> None:
    for n in ("storefront_ramen", "storefront_repair", "storefront_24h"):
        save(trim(Image.open(RAW / f"{n}.png").convert("RGBA")), n)

    for n in ("storey_a", "storey_b", "storey_c"):
        im = Image.open(RAW / f"{n}.png").convert("RGBA")
        a = np.array(im)
        a[..., 3] = 255  # andar é opaco
        save(Image.fromarray(a), n)

    save(trim(Image.open(RAW / "water_tank.png").convert("RGBA")), "water_tank")

    # Varal: só a parte de cima (roupas); o PixelLab desenhou barracos embaixo.
    lau = Image.open(RAW / "laundry_line.png").convert("RGBA").crop((0, 0, 160, 58))
    a = np.array(lau)
    a[44:, :26, 3] = 0       # pedaço de barraco à esquerda
    a[56:, :, 3] = 0
    lau = Image.fromarray(a)
    tall = Image.new("RGBA", (160, 112), (0, 0, 0, 0))
    tall.alpha_composite(lau, (0, 0))
    pole(tall, 2, 2, 112)
    pole(tall, 152, 2, 112)
    save(trim(tall), "laundry_line")

    # Antena: corta o prédio do pé e estica o mastro até a base.
    ant = Image.open(RAW / "antenna.png").convert("RGBA").crop((0, 0, 64, 88))
    a = np.array(ant)
    a[48:, :18, 3] = 0       # telhado que veio junto à esquerda
    ant = Image.fromarray(a)
    tall = Image.new("RGBA", (64, 120), (0, 0, 0, 0))
    tall.alpha_composite(ant, (0, 0))
    pole(tall, 36, 70, 120)  # mastro principal (x≈36) até a base
    save(trim(tall), "antenna")

    # Laje entre andares: concreto com a beirada clara em cima e sombra embaixo.
    rng = np.random.default_rng(3)
    w, h = 192, 10
    s = np.zeros((h, w, 4), np.uint8)
    base = np.array([62, 56, 52])
    for y in range(h):
        shade = 1.25 if y == 1 else (0.55 if y >= h - 3 else 1.0)
        for x in range(w):
            c = np.clip(base * shade + rng.integers(-5, 6), 0, 255)
            s[y, x, :3] = c
            s[y, x, 3] = 255
    s[0, :, :3] = OUT_COL[:3]
    s[h - 1, :, :3] = OUT_COL[:3]
    for x in range(0, w, 7):  # escorridos de ferrugem/limo saindo da laje
        if rng.random() < 0.4:
            s[h - 3:h - 1, x, :3] = RUST[0][:3]
    save(Image.fromarray(s), "slab_strip")


if __name__ == "__main__":
    main()
