"""Prepara a arte do Setor Industrial a partir dos originais do PixelLab em
tools/art_src/industrial/ (gerados com create_image_pixen):

- background.png  -> assets/backgrounds/industrial/bg_industrial[_seamless].png
  (escurecido e dessaturado; a versão emendável é original + espelhada)
- props_sheet.png -> assets/props/industrial/<nome>.png (recorte da grade 3x3;
  armário e rack em 2x para terem altura de móvel ao lado do Eduardo)
- drone.png       -> assets/enemies/drone/drone_{patrol,alert,reboot}.png
  (só a cor do olho muda)

O tileset é feito por tools/gen_industrial_tiles.py (textura plates.png).

Uso (na raiz do projeto):  python3 tools/gen_industrial_art.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools/art_src/industrial")


def out(rel: str) -> str:
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def background() -> None:
    im = np.array(Image.open(os.path.join(SRC, "background.png")).convert("RGB")).astype(float)
    grey = im.mean(axis=2, keepdims=True)
    im = grey + (im - grey) * 0.75          # dessatura um pouco
    im = im * 0.34 + np.array([4, 2, 2])     # escurece (fundo atrás do jogador)
    img = Image.fromarray(np.clip(im, 0, 255).astype(np.uint8), "RGB")
    img.save(out("assets/backgrounds/industrial/bg_industrial.png"))
    seam = Image.new("RGB", (img.width * 2, img.height))
    seam.paste(img, (0, 0))
    seam.paste(img.transpose(Image.FLIP_LEFT_RIGHT), (img.width, 0))
    seam.save(out("assets/backgrounds/industrial/bg_industrial_seamless.png"))
    print("fundo", img.size, seam.size)


PROPS = [
    ["locker", "drum", "gas_cylinders"],
    ["crates", "control_panel", "server_rack"],
    ["generator", "hazard_barrier", "tool_cart"],
]
SCALE2 = {"locker", "server_rack"}


def props() -> None:
    sheet = Image.open(os.path.join(SRC, "props_sheet.png")).convert("RGBA")
    cw = sheet.width / 3
    ch = sheet.height / 3
    for r, row in enumerate(PROPS):
        for c, name in enumerate(row):
            cell = sheet.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch)))
            box = cell.getbbox()
            img = cell.crop(box)
            if name in SCALE2:
                img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
            img.save(out("assets/props/industrial/%s.png" % name))
            print("prop", name, img.size)


def drone() -> None:
    im = Image.open(os.path.join(SRC, "drone.png")).convert("RGBA")
    im = im.crop(im.getbbox())
    a = np.array(im)
    eye = (a[:, :, 0] > 170) & (a[:, :, 1] > 50) & (a[:, :, 1] < 170) & (a[:, :, 2] < 90) & (a[:, :, 3] > 0)
    variants = {
        "patrol": None,
        "alert": (255, 34, 44),
        "reboot": (0, 230, 255),
    }
    for name, col in variants.items():
        b = a.copy()
        if col is not None:
            # mantém o brilho relativo de cada pixel do olho
            lum = b[:, :, 0][eye].astype(float) / 255.0
            for i in range(3):
                b[:, :, i][eye] = np.clip(np.array(col[i]) * (0.55 + 0.45 * lum), 0, 255).astype(np.uint8)
        Image.fromarray(b, "RGBA").save(out("assets/enemies/drone/drone_%s.png" % name))
    print("drone", im.size, "olho px:", int(eye.sum()))


if __name__ == "__main__":
    background()
    props()
    drone()
