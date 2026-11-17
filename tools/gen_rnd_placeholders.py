#!/usr/bin/env python3
"""Greybox da Fase 3 (P&D): sprites provisórios de props, em tons claros e
com contorno escuro, para o layout ser legível antes da arte final (etapa 8).

Uso, na raiz do projeto:  python3 tools/gen_rnd_placeholders.py
Saída: assets/props/rnd/*.png  (sobrescreve)
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "props" / "rnd"
OUTLINE = (12, 10, 10, 255)
PANEL = (168, 182, 196, 255)
PANEL_DARK = (118, 132, 148, 255)
PANEL_LIGHT = (214, 224, 232, 255)
CYAN = (0, 240, 255, 255)
GLASS = (90, 150, 180, 200)


def box(w, h, fill=PANEL):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=fill, outline=OUTLINE)
    return img, d


def counter():
    img, d = box(192, 72)
    d.rectangle([1, 1, 190, 10], fill=PANEL_LIGHT)
    d.line([4, 12, 187, 12], fill=CYAN)
    d.rectangle([70, 24, 122, 54], fill=PANEL_DARK, outline=OUTLINE)  # logotipo
    d.text((79, 32), "OMNI", fill=CYAN)
    return img


def cubicle():
    img, d = box(128, 88, PANEL_DARK)
    d.rectangle([1, 1, 126, 8], fill=PANEL_LIGHT)
    for x in (32, 64, 96):
        d.line([x, 10, x, 86], fill=PANEL)
    d.rectangle([40, 30, 88, 56], fill=(20, 30, 40, 255), outline=OUTLINE)  # monitor
    d.line([44, 34, 84, 34], fill=CYAN)
    return img


def plant():
    img = Image.new("RGBA", (40, 88), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([8, 60, 31, 87], fill=PANEL_LIGHT, outline=OUTLINE)
    d.ellipse([2, 6, 37, 66], fill=(40, 120, 90, 255), outline=OUTLINE)
    d.line([20, 20, 20, 60], fill=(20, 80, 60, 255))
    return img


def cabinet():
    img, d = box(48, 80)
    for y in (4, 30, 56):
        d.rectangle([4, y, 43, y + 20], fill=PANEL_LIGHT, outline=OUTLINE)
        d.line([18, y + 10, 29, y + 10], fill=OUTLINE)
    return img


def lab_bench():
    img = Image.new("RGBA", (144, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 16, 143, 26], fill=PANEL_LIGHT, outline=OUTLINE)
    d.rectangle([6, 26, 137, 63], fill=PANEL, outline=OUTLINE)
    d.line([10, 44, 133, 44], fill=PANEL_DARK)
    for x in (20, 44, 100):  # vidraria
        d.rectangle([x, 2, x + 10, 16], fill=GLASS, outline=OUTLINE)
    d.line([60, 20, 90, 20], fill=CYAN)
    return img


def sample_tank():
    img = Image.new("RGBA", (48, 112), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 0, 43, 10], fill=PANEL_DARK, outline=OUTLINE)
    d.rectangle([6, 10, 41, 98], fill=(60, 190, 200, 140), outline=OUTLINE)
    d.rectangle([4, 98, 43, 111], fill=PANEL_DARK, outline=OUTLINE)
    d.line([12, 20, 12, 90], fill=(200, 255, 255, 160))
    return img


def ceiling_light():
    """2 quadros lado a lado (aceso / apagado), como os neons de 2 frames."""
    w, h = 96, 14
    img = Image.new("RGBA", (w * 2, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, lit in enumerate((True, False)):
        x = i * w
        d.rectangle([x, 0, x + w - 1, 5], fill=PANEL_DARK, outline=OUTLINE)
        d.rectangle([x + 4, 5, x + w - 5, h - 1],
                    fill=(230, 252, 255, 255) if lit else (60, 70, 80, 255), outline=OUTLINE)
        if lit:
            d.line([x + 8, 9, x + w - 9, 9], fill=CYAN)
    return img


def exec_elevator():
    img, d = box(160, 176, PANEL_DARK)
    d.rectangle([12, 20, 147, 175], fill=PANEL, outline=OUTLINE)
    d.line([80, 20, 80, 175], fill=OUTLINE)
    d.rectangle([60, 4, 100, 14], fill=(20, 30, 40, 255), outline=OUTLINE)
    d.text((66, 4), "N", fill=CYAN)
    d.line([12, 22, 147, 22], fill=CYAN)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in [
        ("reception_counter", counter), ("cubicle", cubicle), ("plant", plant),
        ("filing_cabinet", cabinet), ("lab_bench", lab_bench), ("sample_tank", sample_tank),
        ("ceiling_light_flicker_2f", ceiling_light), ("exec_elevator", exec_elevator),
    ]:
        fn().save(OUT / f"{name}.png")
        print("  salvo", OUT / f"{name}.png")


if __name__ == "__main__":
    main()
