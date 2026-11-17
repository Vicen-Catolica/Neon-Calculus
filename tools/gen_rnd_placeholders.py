#!/usr/bin/env python3
"""Fase 3 (P&D): painel de luz do teto (2 quadros, aceso/apagado), desenhado
aqui. Os outros props do greybox foram trocados pela arte do PixelLab
(tools/gen_rnd_art.py), que usa os mesmos nomes de arquivo.

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


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in [("ceiling_light_flicker_2f", ceiling_light)]:
        fn().save(OUT / f"{name}.png")
        print("  salvo", OUT / f"{name}.png")


if __name__ == "__main__":
    main()
