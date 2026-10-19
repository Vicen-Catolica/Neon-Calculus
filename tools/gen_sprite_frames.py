"""Gera os SpriteFrames (.tres) do Eduardo e dos guardas a partir das pastas
assets/characters/<personagem>/<animação>/frame_N.png.

Uso (na raiz do projeto):  python tools/gen_sprite_frames.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (animação, pasta, loop, fps)
EDUARDO = [
    ("idle", "idle", True, 8.0),
    ("walk", "walk", True, 10.0),
    ("run", "run", True, 12.0),
    ("crouching", "crouching", False, 14.0),
    ("crouch_idle", "crouch_idle", True, 6.0),
    ("crouch_walk", "crouch_walk", True, 9.0),
    ("hack_start", "hack_start", False, 12.0),
    ("hack", "hack", True, 6.0),
    ("hack_fx", "hack_fx", True, 6.0),
    ("jump", "jump", False, 14.0),
    ("fall", "fall", True, 8.0),
    ("land", "land", False, 16.0),
    ("ladder_enter", "ladder_enter", False, 14.0),
    ("ladder_climb", "ladder_climb", True, 9.0),
]

GUARD = [
    ("idle", "idle", True, 7.0),
    ("patrol", "patrol", True, 9.0),
    ("suspicious", "suspicious", True, 5.0),
    ("alert", "alert", False, 10.0),
    ("chase", "chase", True, 12.0),
    ("shoot", "shoot", False, 12.0),
    ("stunned", "stunned", False, 10.0),
]


def frames_in(folder):
    names = [f for f in os.listdir(folder) if f.startswith("frame_") and f.endswith(".png")]
    return sorted(names, key=lambda n: int(n[6:-4]))


def build(anims, base_rel, out_rel):
    ext = []
    blocks = []
    for name, folder, loop, fps in anims:
        rel = f"{base_rel}/{folder}"
        frames = []
        for f in frames_in(os.path.join(ROOT, rel.replace("res://", ""))):
            ext.append(f"{rel}/{f}")
            frames.append(len(ext))
        frame_txt = ",\n".join(
            '{\n"duration": 1.0,\n"texture": ExtResource("%d")\n}' % i for i in frames)
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                      % (frame_txt, "true" if loop else "false", name, fps))
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(ext) + 1} format=3]', ""]
    for i, path in enumerate(ext, 1):
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{i}"]')
    lines += ["", "[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    out = os.path.join(ROOT, out_rel)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", newline="\n", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(out_rel, len(anims), "animações,", len(ext), "texturas")


if __name__ == "__main__":
    build(EDUARDO, "res://assets/characters/eduardo", "scenes/player/eduardo_frames.tres")
    build(GUARD, "res://assets/characters/guard/v1", "scenes/enemies/guard_v1_frames.tres")
    build(GUARD, "res://assets/characters/guard/v2", "scenes/enemies/guard_v2_frames.tres")
