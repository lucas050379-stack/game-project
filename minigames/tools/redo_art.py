# Cloudflare 로 뽑았던 그림을 GPT 로 다시 뽑아 넣기(11-10) — 강호일생(전부 옅은 채색 수묵화) · 스카이 어설트의 남은 것.
#   <sprite-gen venv>/python -I tools/redo_art.py [모음 그림 폴더]     (minigames/ 에서. Pillow · numpy)   그다음 lossy_big.gd · --import
# 강호일생: art/source/gh2_<이름>_g1110_01.png — 예전 그림을 참조로 같은 구도를 수묵화로 다시 그린 것(가짜 한자 · 낙관 없음).
#   장면 56장은 1024² 그대로, 혼처 초상 12장은 429×640 으로 잘라 예전 그림의 알파(둥근 모서리)를 입힌다.
# 스카이: art/source/sky6_<이름>_g1110_01.png — 예전 그림을 참조로 굵은 픽셀풍으로. 자홍 바탕을 빼고 예전과 같은 크기의 정사각에 앉힌다.
# 월드 러너는 예전 길(art/post.bat → tools/runner_art.gd)을 그대로 쓴다 — tools/redo_runner.sh.
import glob
import os
import sys
import numpy as np
from PIL import Image


def keyed(path):
    a = np.array(Image.open(path).convert("RGBA")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    key = (r > 170) & (b > 170) & (g < 110) & (abs(r - b) < 70)
    a[..., 3] = np.where(key, 0, 255)
    spill = (~key) & (r > g + 60) & (b > g + 60)
    avg = (g + np.minimum(r, b)) // 2
    a[..., 0] = np.where(spill, avg, r)
    a[..., 2] = np.where(spill, avg, b)
    im = Image.fromarray(a.astype("uint8"), "RGBA")
    return im.crop(im.getbbox())


def cover(im, w, h):
    k = max(float(w) / im.width, float(h) / im.height)
    im = im.resize((int(im.width * k + 0.5), int(im.height * k + 0.5)), Image.LANCZOS)
    x = (im.width - w) // 2
    y = (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


n = 0
for f in sorted(glob.glob("art/source/gh2_*_g1110_01.png")):
    name = os.path.basename(f)[4:-len("_g1110_01.png")]
    dst = "art/gangho/%s.png" % name
    if not os.path.exists(dst):
        continue
    old = Image.open(dst)
    im = cover(Image.open(f).convert("RGB"), old.width, old.height)
    if old.mode == "RGBA":   # 혼처 초상 — 예전 그림의 알파를 그대로
        im = im.convert("RGBA")
        im.putalpha(old.getchannel("A"))
    im.save(dst)
    n += 1
for f in sorted(glob.glob("art/source/sky6_*_g1110_01.png")):
    name = os.path.basename(f)[5:-len("_g1110_01.png")]
    dst = "art/sky/%s.png" % name
    if not os.path.exists(dst):
        continue
    size = Image.open(dst).width
    im = keyed(f)
    s = max(im.size)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.paste(im, ((s - im.width) // 2, (s - im.height) // 2))
    sq.resize((size, size), Image.LANCZOS).save(dst)
    n += 1
# 스카이 아이템 둘(파워업 · 봄) - 참조 없이 새로 뽑은 것. 고리 안에 갇힌 자홍까지 지워야 해서 여기서 넣는다(post.gd 는 가장자리에서만 지운다)
for nm in ["power", "bomb"]:
    fs2 = sorted(glob.glob("art/source/sky7_item_%s_g*_01.png" % nm))
    if fs2:
        im = keyed(fs2[-1])
        s2 = max(im.size)
        sq = Image.new("RGBA", (s2, s2), (0, 0, 0, 0))
        sq.paste(im, ((s2 - im.width) // 2, (s2 - im.height) // 2))
        sq.resize((128, 128), Image.LANCZOS).save("art/sky/sky_item_%s.png" % nm)
        n += 1
fs = sorted(glob.glob("art/source/sky5_bg_select_g*_01.png"))
if fs:
    cover(Image.open(fs[-1]).convert("RGB"), 1024, 1024).save("art/sky/sky_bg_select.png")
    n += 1
if os.path.exists("art/sky/sky_poster_5.png"):   # 허브 표지 — 예전 용 보스 그림 대신 지금 보스(공중 전함)의 포스터에서
    p = Image.open("art/sky/sky_poster_5.png").convert("RGB")
    s = p.height
    p.crop(((p.width - s) // 2, 0, (p.width - s) // 2 + s, s)).resize((1024, 1024), Image.LANCZOS).save("art/sky/sky_card.png")
    n += 1
print("put", n)
if len(sys.argv) > 1:
    for game in ["gangho"]:
        fs = sorted(glob.glob("art/%s/*.png" % game))
        cols = 10
        W = Image.new("RGB", (cols * 150, ((len(fs) + cols - 1) // cols) * 150), (70, 74, 82))
        for k, f in enumerate(fs):
            im = Image.open(f).convert("RGBA")
            im.thumbnail((146, 146))
            W.paste(im, ((k % cols) * 150 + 2, (k // cols) * 150 + 2), im)
        W.save(os.path.join(sys.argv[1], "redo_%s.png" % game))
