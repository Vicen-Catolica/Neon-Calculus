"""Prepara a arte do Setor Industrial a partir dos originais do PixelLab em
tools/art_src/industrial/ (gerados com create_image_pixen):

- background.png  -> assets/backgrounds/industrial/bg_industrial[_seamless].png
  (escurecido e dessaturado; a versão emendável é original + espelhada)
- props_sheet.png -> assets/props/industrial/<nome>.png (recorte da grade 3x3;
  armário e rack em 2x para terem altura de móvel ao lado do Eduardo)
- drone.png       -> assets/enemies/drone/drone_{patrol,alert,reboot}.png
  (só a cor do olho muda)
- valve.png       -> assets/objects/valve/valve_{closed,open}.png + pipe_segment.png
  (volante vermelho fechado / ciano aberto; fatia do topo repete o cano até o teto)
- conveyor.png    -> assets/objects/conveyor/conveyor_{left,mid,right}.png
  (pontas + trecho do meio que se repete e "anda")
- robot_arm.png, elevator.png -> assets/props/industrial/

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


def _cropped(name: str) -> Image.Image:
    im = Image.open(os.path.join(SRC, name)).convert("RGBA")
    return im.crop(im.getbbox())


def valve() -> None:
    im = _cropped("valve.png")
    a = np.array(im)
    red = (a[:, :, 0] > 140) & (a[:, :, 1] < 80) & (a[:, :, 2] < 80) & (a[:, :, 3] > 0)
    im.save(out("assets/objects/valve/valve_closed.png"))
    b = a.copy()
    lum = b[:, :, 0][red].astype(float) / 255.0
    for i, v in enumerate((0, 235, 255)):
        b[:, :, i][red] = np.clip(v * (0.45 + 0.55 * lum), 0, 255).astype(np.uint8)
    Image.fromarray(b, "RGBA").save(out("assets/objects/valve/valve_open.png"))
    # fatia de 6 px do topo do cano: repete para cima até o teto
    im.crop((0, 0, im.width, 6)).save(out("assets/objects/valve/pipe_segment.png"))
    ys, xs = np.nonzero(red)
    print("válvula", im.size, "volante y=%d..%d x=%d..%d" % (ys.min(), ys.max(), xs.min(), xs.max()))


def conveyor() -> None:
    im = _cropped("conveyor.png")
    a = np.array(im).astype(int)
    cap = 16
    # período do padrão do meio (rolos/garras): menor diferença entre colunas
    best, best_err = 16, 1e9
    for p in range(8, 41):
        x0, x1 = cap + 4, im.width - cap - 4 - p
        if x1 <= x0:
            continue
        err = np.abs(a[:, x0:x1] - a[:, x0 + p:x1 + p]).mean()
        if err < best_err:
            best, best_err = p, err
    mid_x = im.width // 2 - best // 2
    im.crop((0, 0, cap, im.height)).save(out("assets/objects/conveyor/conveyor_left.png"))
    im.crop((im.width - cap, 0, im.width, im.height)).save(out("assets/objects/conveyor/conveyor_right.png"))
    im.crop((mid_x, 0, mid_x + best, im.height)).save(out("assets/objects/conveyor/conveyor_mid.png"))
    print("esteira", im.size, "período do meio", best, "erro %.1f" % best_err)


def machines() -> None:
    for name in ("robot_arm", "elevator"):
        im = _cropped(name + ".png")
        im.save(out("assets/props/industrial/%s.png" % name))
        print(name, im.size)


if __name__ == "__main__":
    background()
    props()
    drone()
    valve()
    conveyor()
    machines()
