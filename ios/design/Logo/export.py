"""Regenerates the logo assets in Assets.xcassets from art.html.

    python3 Design/Logo/export.py

Needs Google Chrome and Pillow. Point sizes match TokiyoLogoView (0.082 pt per
icon unit) and the launch screen (240 pt wide).
"""
import os, subprocess, tempfile
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "Tokiyo Casino", "Res", "Assets.xcassets")
RENDER = os.path.join(HERE, "render.sh")
K = 0.082
WORD_CROP = (152, 160, 1876, 952)
tmp = tempfile.mkdtemp()


def render(piece, mode, w, h, size=None):
    out = os.path.join(tmp, f"{piece}-{mode}.png")
    subprocess.run([RENDER, piece, mode, str(w), str(h), out] + ([str(size)] if size else []), check=True)
    return Image.open(out).convert("RGBA")


def save(im, w_pt, h_pt, name, mode):
    for sc in (2, 3):
        im.resize((round(w_pt * sc), round(h_pt * sc)), Image.LANCZOS).save(
            os.path.join(ASSETS, f"{name}.imageset", f"{name}-{mode}@{sc}x.png"))


icons = os.path.join(ASSETS, "AppIcon.appiconset")
render("icon", "light", 1024, 1024).convert("RGB").save(os.path.join(icons, "appstore.png"))
dark = render("icon", "dark", 1024, 1024).convert("RGB")
dark.save(os.path.join(icons, "appstore-dark.png"))
dark.convert("L").convert("RGB").save(os.path.join(icons, "appstore-tinted.png"))

logos = {m: render("logo", m, 2048, 2048, 2048) for m in ("light", "dark")}
boxes = [im.getchannel("A").point(lambda a: 255 if a > 4 else 0).getbbox() for im in logos.values()]
crop = (min(b[0] for b in boxes) - 12, min(b[1] for b in boxes) - 12,
        max(b[2] for b in boxes) + 12, max(b[3] for b in boxes) + 12)

for mode in ("light", "dark"):
    for idx in "AQ":
        save(render("card" + idx, mode, 572, 800, 572), 286 * K, 400 * K, f"TokiyoCard{idx}", mode)
    save(render("cardK", mode, 636, 892, 636), 318 * K, 446 * K, "TokiyoCardK", mode)
    word = render("word", mode, 2048, 1024, 2048).crop(WORD_CROP)
    save(word, 42 * word.width / word.height, 42, "TokiyoWordmark", mode)
    logo = logos[mode].crop(crop)
    save(logo, 240, 240 * logo.height / logo.width, "TokiyoLogo", mode)
print("done")
