#!/usr/bin/env python3
"""Efeitos sonoros sintetizados (numpy -> WAV 16 bits mono, 44,1 kHz).

Não há banco de sons no projeto e o gerador de SFX do PixelLab exige outro
plano; estes são provisórios, mas com a cara do jogo (bipes digitais, estática).
Cada som é um arquivo em assets/sfx/<nome>.wav: para trocar por um gravado,
basta sobrescrever o arquivo com o mesmo nome (o autoload Sfx carrega por nome).

    python3 tools/gen_sfx.py            # gera todos
    python3 tools/gen_sfx.py taser      # só os que contêm "taser" no nome
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, a=0.005, r=0.05, shape=2.0):
    """Envelope ataque/decaimento (em segundos) para n amostras."""
    e = np.ones(n)
    na = max(1, int(a * SR))
    nr = max(1, min(n - na, int(r * SR)))
    e[:na] = np.linspace(0, 1, na)
    e[n - nr:] = np.linspace(1, 0, nr) ** shape
    return e


def square(f, x, duty=0.5):
    return np.where((f * x) % 1.0 < duty, 1.0, -1.0)


def tri(f, x):
    return 2.0 * np.abs(2.0 * ((f * x) % 1.0) - 1.0) - 1.0


def lowpass(x, k):
    """Média móvel simples (k amostras): tira o chiado agudo."""
    if k <= 1:
        return x
    return np.convolve(x, np.ones(k) / k, mode="same")


def noise(n):
    return rng.uniform(-1, 1, n)


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    # 4 ms de fade no fim para não estalar
    k = min(len(x), int(0.004 * SR))
    x[-k:] *= np.linspace(1, 0, k)
    data = (x * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("ok", name, f"{len(x) / SR:.2f}s")


# --- Voice blips (GDD §9): um bipe curto por letra, timbre por falante -------

def blip_sine():
    # SINE: IA aliada, voz clara e aguda (seno + leve FM, um "pling").
    x = t(0.055)
    f = 1320
    s = np.sin(2 * np.pi * f * x + 0.8 * np.sin(2 * np.pi * f * 2 * x))
    return s * env(len(x), 0.002, 0.045)


def blip_eduardo():
    # Eduardo: médio, quadrado filtrado (voz humana "de 8 bits").
    x = t(0.06)
    s = lowpass(square(220, x, 0.4), 6) * 0.8 + 0.3 * np.sin(2 * np.pi * 440 * x)
    return s * env(len(x), 0.003, 0.05)


def blip_vance():
    # Dr. Vance: grave e quente (triângulo), um pouco mais longo.
    x = t(0.07)
    s = tri(165, x) + 0.25 * np.sin(2 * np.pi * 330 * x)
    return s * env(len(x), 0.004, 0.06)


def blip_axioma():
    # Axioma: grave, distorcido, com bitcrush e um fio de ruído (glitch).
    x = t(0.075)
    s = square(98, x, 0.3) * 0.7 + np.sin(2 * np.pi * 49 * x) * 0.5
    s = np.round(s * 4) / 4
    s += 0.25 * lowpass(noise(len(x)), 3)
    return np.tanh(s * 2.5) * env(len(x), 0.002, 0.06)


def blip_ui():
    # Falantes sem timbre próprio (sistema, rádio).
    x = t(0.04)
    return square(880, x, 0.25) * env(len(x), 0.001, 0.03) * 0.6


# --- Guardas ----------------------------------------------------------------

def taser():
    # Choque: estalos elétricos com zumbido de 120 Hz modulado.
    x = t(0.55)
    n = len(x)
    hum = square(120, x, 0.5) * 0.5 + np.sin(2 * np.pi * 60 * x) * 0.3
    crack = noise(n) * (rng.random(n) < 0.08)
    crack = lowpass(crack, 2) * 3.0
    buzz = noise(n) * (0.5 + 0.5 * square(37, x))
    s = hum + crack + 0.6 * buzz
    return np.tanh(s * 1.5) * env(n, 0.003, 0.2, 1.5)


def detect():
    # "!" de quem te viu: duas notas subindo, rápidas e afiadas.
    parts = []
    for f, d in ((880, 0.07), (1760, 0.16)):
        x = t(d)
        s = square(f, x, 0.25) * 0.6 + np.sin(2 * np.pi * f * x)
        parts.append(s * env(len(x), 0.002, d * 0.7))
    return np.concatenate(parts)


def suspicious():
    # "?" desconfiado: um bipe que sobe devagar.
    x = t(0.22)
    f = np.linspace(520, 780, len(x))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * env(len(x), 0.01, 0.12) * 0.7


def radio():
    # Rádio pedindo reforços: estática, dois bipes curtos, estática.
    st1 = lowpass(noise(int(0.12 * SR)), 4) * env(int(0.12 * SR), 0.005, 0.05)
    beeps = []
    for _ in range(2):
        x = t(0.06)
        beeps.append(np.sin(2 * np.pi * 1200 * x) * env(len(x), 0.002, 0.02))
        beeps.append(np.zeros(int(0.04 * SR)))
    st2 = lowpass(noise(int(0.18 * SR)), 4) * env(int(0.18 * SR), 0.005, 0.12)
    return np.concatenate([st1 * 0.5, *beeps, st2 * 0.5])


def lost():
    # Perderam o rastro: bipe descendo, suave.
    x = t(0.3)
    f = np.linspace(700, 380, len(x))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return tri(1, ph / (2 * np.pi)) * env(len(x), 0.01, 0.2) * 0.6


# --- Eduardo ----------------------------------------------------------------

def step(seed, weight=1.0):
    # Passo: batida curta grave + chiado de sola (metal/concreto).
    r = np.random.default_rng(seed)
    n = int(0.09 * SR)
    x = t(0.09)
    thump = np.sin(2 * np.pi * (70 + 15 * r.random()) * x) * np.exp(-x * 60)
    scuff = lowpass(r.uniform(-1, 1, n), 3 + int(3 * r.random())) * np.exp(-x * 45)
    return (thump * weight + scuff * 0.6) * env(n, 0.001, 0.05)


def hide():
    # Encolher na sombra: roçar de tecido (ruído filtrado em "swoosh").
    n = int(0.32 * SR)
    x = t(0.32)
    s = lowpass(noise(n), 10) * np.sin(np.pi * x / 0.32) ** 2
    hum = np.sin(2 * np.pi * 180 * x) * np.exp(-x * 12) * 0.2
    return s + hum


def unhide():
    n = int(0.2 * SR)
    x = t(0.2)
    return lowpass(noise(n), 7) * np.sin(np.pi * x / 0.2) ** 3


def jump():
    x = t(0.08)
    n = len(x)
    return lowpass(noise(n), 4) * env(n, 0.002, 0.06) * 0.6 + \
        np.sin(2 * np.pi * 90 * x) * np.exp(-x * 50) * 0.5


def land():
    x = t(0.14)
    n = len(x)
    return np.sin(2 * np.pi * 55 * x) * np.exp(-x * 30) + \
        lowpass(noise(n), 5) * np.exp(-x * 35) * 0.7


def hurt():
    # Choque recebido no traje: zumbido curto + queda de tom.
    x = t(0.25)
    f = np.linspace(400, 120, len(x))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = square(1, ph / (2 * np.pi), 0.5) * 0.6 + lowpass(noise(len(x)), 2) * 0.4
    return np.tanh(s * 2) * env(len(x), 0.002, 0.15)


# --- Hack -------------------------------------------------------------------

def hack_open():
    # Entrar na visão de hack: varredura subindo + "lock".
    x = t(0.35)
    f = np.geomspace(200, 1600, len(x))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * env(len(x), 0.01, 0.1) * 0.7
    y = t(0.08)
    lock = square(2000, y, 0.5) * env(len(y), 0.001, 0.06) * 0.4
    return np.concatenate([s, lock])


def hack_key():
    x = t(0.035)
    return (square(1500, x, 0.3) * 0.5 + np.sin(2 * np.pi * 750 * x)) * env(len(x), 0.001, 0.03)


def hack_ok():
    # Equação certa: arpejo maior subindo (dó-mi-sol-dó).
    parts = []
    for f in (523, 659, 784, 1047):
        x = t(0.07)
        parts.append((np.sin(2 * np.pi * f * x) + 0.3 * square(f, x, 0.25)) * env(len(x), 0.002, 0.05))
    x = t(0.2)
    parts.append(np.sin(2 * np.pi * 1047 * x) * env(len(x), 0.002, 0.18) * 0.7)
    return np.concatenate(parts)


def hack_fail():
    # Erro: dois "buzz" graves.
    parts = []
    for _ in range(2):
        x = t(0.12)
        s = square(110, x, 0.5) * 0.7 + square(116, x, 0.5) * 0.5
        parts.append(lowpass(s, 4) * env(len(x), 0.002, 0.04))
        parts.append(np.zeros(int(0.05 * SR)))
    return np.concatenate(parts)


def hack_abort():
    x = t(0.25)
    f = np.geomspace(1200, 150, len(x))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * env(len(x), 0.002, 0.1) * 0.7


def ui_click():
    x = t(0.025)
    return square(1800, x, 0.5) * env(len(x), 0.001, 0.02) * 0.5


def sonar():
    # Ping Sonar: "ping" com eco.
    x = t(0.9)
    s = np.sin(2 * np.pi * 1400 * x) * np.exp(-x * 7)
    echo = np.zeros_like(s)
    d = int(0.22 * SR)
    echo[d:] = s[:-d] * 0.35
    return s + echo


def camo():
    # Camuflagem: chiado descendo + brilho.
    x = t(0.45)
    f = np.geomspace(3000, 300, len(x))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) * 0.5 + lowpass(noise(len(x)), 3) * 0.3) * env(len(x), 0.01, 0.3)


def alarm():
    # Lockdown: sirene de dois tons (um ciclo; o jogo repete).
    parts = []
    for f in (740, 554):
        x = t(0.35)
        parts.append((square(f, x, 0.5) * 0.4 + np.sin(2 * np.pi * f * x)) * env(len(x), 0.01, 0.03))
    return np.concatenate(parts)


SOUNDS = {
    "blip_sine": (blip_sine, 0.55),
    "blip_eduardo": (blip_eduardo, 0.55),
    "blip_vance": (blip_vance, 0.55),
    "blip_axioma": (blip_axioma, 0.6),
    "blip_ui": (blip_ui, 0.45),
    "taser": (taser, 0.75),
    "detect": (detect, 0.65),
    "suspicious": (suspicious, 0.5),
    "radio": (radio, 0.55),
    "lost": (lost, 0.45),
    "step_1": (lambda: step(1), 0.45),
    "step_2": (lambda: step(2), 0.45),
    "step_3": (lambda: step(3), 0.45),
    "step_4": (lambda: step(4), 0.45),
    "hide": (hide, 0.55),
    "unhide": (unhide, 0.45),
    "jump": (jump, 0.45),
    "land": (land, 0.55),
    "hurt": (hurt, 0.6),
    "hack_open": (hack_open, 0.55),
    "hack_key": (hack_key, 0.4),
    "hack_ok": (hack_ok, 0.6),
    "hack_fail": (hack_fail, 0.6),
    "hack_abort": (hack_abort, 0.55),
    "ui_click": (ui_click, 0.4),
    "sonar": (sonar, 0.55),
    "camo": (camo, 0.5),
    "alarm": (alarm, 0.5),
}

if __name__ == "__main__":
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    for name, (fn, gain) in SOUNDS.items():
        if only in name:
            save(name, fn(), gain)
