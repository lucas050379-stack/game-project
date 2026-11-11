# 떡 하나 — GPT(codex)로 뽑은 tg2_* 그림 넣기(11-11). art/source/tg2_<이름>_g<월일_시각>_01.png(가장 최근 것) → art/tiger/tg_<이름>.png
#   <sprite-gen venv>/python -I tools/tiger_gpt.py [mirror]     그다음 lossy_big.gd · --import
# 물건 = 마젠타를 빼고 테두리에 맞춰 자름. 배경(tg2_back_N) = 높이 640 으로 줄여 그대로(뒤집지 않는다 — 이어 붙는 그림). `mirror` 를 주면 예전처럼 뒤집어 붙인다.
import glob
import os
import re
import sys
import numpy as np
from PIL import Image, ImageOps

SIZE = [("plank", 512), ("burr", 192), ("axe", 384), ("millstone", 320), ("bolt", 256), ("rock", 256), ("stump", 256), ("tall", 384), ("branch", 384),
        ("gotgam", 384), ("pit", 384), ("pestle", 384), ("flyer", 256), ("spike", 192), ("ceil", 384)]


def keyed(path):
    a = np.array(Image.open(path).convert("RGBA")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    key = (r > 170) & (b > 170) & (g < 110) & (abs(r - b) < 70)
    a[..., 3] = np.where(key, 0, 255)
    spill = (~key) & (r > 150) & (b > 150) & (g < 140)
    a[..., 0] = np.where(spill, g, r)
    a[..., 2] = np.where(spill, g, b)
    im = Image.fromarray(a.astype("uint8"), "RGBA")
    return im.crop(im.getbbox())


latest = {}
for f in sorted(glob.glob("art/source/tg[23]_*_g*_01.png")):
    m = re.match(r"(tg[23]_.+)_g\d{4}_\d{6}_01\.png$", os.path.basename(f))
    if m:
        latest[m.group(1)] = f
n = 0
for name, f in sorted(latest.items()):
    out = "art/tiger/tg_" + name[4:] + ".png"
    if name.startswith("tg3_near_"):   # 가까운 배경 띠(11-11) — 하늘 마젠타를 빼고 폭 1024 로, 위아래는 그림이 있는 데까지
        im = keyed(f)
        im = im.resize((1024, int(im.height * 1024 / im.width)), Image.LANCZOS)
        im.save("art/tiger/tg_bg_%s_near.png" % name[-1])
        n += 1
        continue
    if name == "tg2_heaven":
        continue   # 하늘나라 배경은 따로(높이 720)
    if name.startswith("tg2_back_"):
        im = Image.open(f).convert("RGB")
        im = im.resize((int(im.width * 640 / im.height), 640), Image.LANCZOS)
        if "mirror" in sys.argv:
            o = Image.new("RGB", (im.width * 2, 640))
            o.paste(im, (0, 0))
            o.paste(ImageOps.mirror(im), (im.width, 0))
            im = o
        im.save(out)
    else:
        mx = next((s for k, s in SIZE if k in name), 256)
        im = keyed(f)
        im.thumbnail((mx, mx), Image.LANCZOS)
        im.save(out)
    n += 1
print("put", n)
