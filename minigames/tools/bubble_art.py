# "물거품처럼 사라져줘" 그림 넣기 — art/source 의 GPT 후보(bb_*_g<월일>_*.png, 가장 최근 것)를 잘라 art/bubble/ 에.
#   <sprite-gen venv>/python -I tools/bubble_art.py      그다음 --import
# 시트(네 칸 한 줄) = 마젠타를 빼고 투명 기둥으로 네 덩어리를 찾아 자른 뒤, 같은 배율로 줄여 같은 크기 판에 아래를 맞춘다(bb_<name>_0..3).
# 물건(보스 · 상어 · 거품 · 터짐 · 발판) = 마젠타를 빼고 테두리에 맞춰 자름. 배경 · 표지 · 카드 = 그대로 줄임.
import glob, os
import numpy as np
from PIL import Image

os.makedirs("art/bubble", exist_ok=True)


def latest(n):
    fs = sorted(glob.glob("art/source/%s_g*_01.png" % n))
    return fs[-1] if fs else None


def keyed(path, crop=True):
    a = np.array(Image.open(path).convert("RGBA")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    key = (r > 170) & (b > 170) & (g < 110) & (abs(r - b) < 70)
    a[..., 3] = np.where(key, 0, 255)
    spill = (~key) & (r > 150) & (b > 150) & (g < 140)
    a[..., 0] = np.where(spill, g, r)
    a[..., 2] = np.where(spill, g, b)
    im = Image.fromarray(a.astype("uint8"), "RGBA")
    return im.crop(im.getbbox()) if crop else im


def split4(im):
    al = np.array(im)[..., 3] > 40
    col = al.sum(axis=0) > 2
    runs, x = [], 0
    W = len(col)
    while x < W:
        if col[x]:
            s = x
            while x < W and col[x]:
                x += 1
            runs.append([s, x])
        x += 1
    while len(runs) > 4:   # 작은 조각(땀방울 · 속도 선)은 가까운 덩어리에 붙인다
        gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        i = gaps.index(min(gaps))
        runs[i] = [runs[i][0], runs[i + 1][1]]
        del runs[i + 1]
    if len(runs) != 4:   # 못 찾으면 같은 폭 넷
        runs = [[W * k // 4, W * (k + 1) // 4] for k in range(4)]
    out = []
    for s, e in runs:
        c = im.crop((s, 0, e, im.height))
        out.append(c.crop(c.getbbox()))
    return out


n = 0
SHEET = {"bb_mer_a": 160, "bb_mer_b": 160, "bb_mer2_a": 160, "bb_mer2_b": 160, "bb_en_0": 128, "bb_en_1": 128, "bb_en_2": 128,
         "bb_en_3": 128, "bb_en_4": 128, "bb_items": 96, "bb_powers": 96}
for name, mx in SHEET.items():
    f = latest(name)
    if f is None:
        continue
    im = keyed(f, False)
    if name == "bb_items":   # GPT 가 위에 인어 줄을 더 그렸다(11-11) — 맨 아래 줄만
        rows = np.array(im)[..., 3].max(axis=1) > 40
        y = len(rows) - 1
        while y > 0 and not rows[y]:
            y -= 1
        while y > 0 and rows[y]:
            y -= 1
        im = im.crop((0, y, im.width, im.height))
    fr = split4(im)
    k = mx / float(max(max(c.width, c.height) for c in fr))
    fr = [c.resize((max(1, int(c.width * k)), max(1, int(c.height * k))), Image.LANCZOS) for c in fr]
    W = max(c.width for c in fr)
    H = max(c.height for c in fr)
    for i, c in enumerate(fr):
        cv = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cv.paste(c, ((W - c.width) // 2, H - c.height))
        cv.save("art/bubble/%s_%d.png" % (name, i))
        n += 1
OBJ = {"bb_boss_0": 256, "bb_boss_1": 256, "bb_boss_2": 256, "bb_boss_3": 256, "bb_boss_4": 256, "bb_shark": 192,
       "bb_bubble": 128, "bb_pop": 160, "bb_ink": 192}
for name, mx in OBJ.items():
    f = latest(name)
    if f is None:
        continue
    im = keyed(f)
    im.thumbnail((mx, mx), Image.LANCZOS)
    im.save("art/bubble/%s.png" % name)
    n += 1
for t in range(5):
    f = latest("bb_tile_%d" % t)
    if f:
        im = keyed(f)
        im = im.resize((int(im.width * 64 / im.height), 64), Image.LANCZOS)
        im.save("art/bubble/bb_tile_%d.png" % t)
        n += 1
    f = latest("bb_bg_%d" % t)
    if f:
        Image.open(f).convert("RGB").resize((1280, 720), Image.LANCZOS).save("art/bubble/bb_bg_%d.png" % t)
        n += 1
f = latest("bb_title")
if f:
    Image.open(f).convert("RGB").resize((1280, 720), Image.LANCZOS).save("art/bubble/bb_title.png")
    n += 1
f = latest("bb_card")
if f:
    im = Image.open(f).convert("RGB")
    s = min(im.size)
    im.crop(((im.width - s) // 2, (im.height - s) // 2, (im.width + s) // 2, (im.height + s) // 2)).resize((512, 512), Image.LANCZOS).save("art/bubble/bb_card.png")
    n += 1
print("put", n)
# 크기 맞추기(BbArt.fit_h)에 쓰는 "그림이 있는 곳" 크기 — 게임이 그림을 읽어 재면 웹(WebGL)에서 GPU 를 거꾸로 읽어야 해서, 여기서 재 코드로 적는다
used = {}
for n in ["bb_mer_a_0", "bb_mer2_a_0"] + ["bb_en_%d_0" % k for k in range(5)]:
    p = "art/bubble/%s.png" % n
    if os.path.exists(p):
        im = Image.open(p)
        bb = im.getbbox()
        used[n] = (im.height, bb[2] - bb[0], bb[3] - bb[1])
with open("src/bubble/fit.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write("class_name BbFit\nextends RefCounted\n\n## tools/bubble_art.py 가 만든다(손으로 고치지 마세요). 그림 이름 -> [판 높이, 그림이 있는 곳 폭, 높이](px)\n\nconst USED := {\n")
    for n, v in used.items():
        f.write('\t"%s": [%d, %d, %d],\n' % (n, v[0], v[1], v[2]))
    f.write("}\n")
print("fit", len(used))
