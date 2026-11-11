# "버거왕" 그림 넣기 — art/source 의 GPT 시트(bg_*_g<월일>_*.png, 가장 최근 것)를 잘라 art/burger/ 에.
#   <sprite-gen venv>/python -I tools/burger_art.py [모음 그림 경로]     (minigames/ 에서. Pillow · numpy)   그다음 lossy_big.gd · --import
# 재료 · 물건 시트 = 자홍 바탕을 빼고 열마다 비어 있는 틈으로 나눈다(왼쪽부터 정해 둔 이름 순서).
# 손님 시트 = 표정 네 칸을 같은 틀(아래 맞춤)에. 가게 배경 · 표지 = 16:9 로 잘라 줄인다.
import glob
import os
import sys
import numpy as np
from PIL import Image

OUT = "art/burger/"
os.makedirs(OUT, exist_ok=True)


def latest(n):
    fs = sorted(glob.glob("art/source/%s_g*_01.png" % n))
    return fs[-1] if fs else None


def keyed(path):
    a = np.array(Image.open(path).convert("RGBA")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    key = (r > 170) & (b > 170) & (g < 110) & (abs(r - b) < 70)
    a[..., 3] = np.where(key, 0, 255)
    spill = (~key) & (r > g + 60) & (b > g + 60)   # 테두리에 남은 분홍 기운
    avg = (g + np.minimum(r, b)) // 2
    a[..., 0] = np.where(spill, avg, r)
    a[..., 2] = np.where(spill, avg, b)
    return Image.fromarray(a.astype("uint8"), "RGBA")


def row_split(path, count):
    im = keyed(path)
    cols = (np.array(im)[..., 3] > 0).sum(axis=0) > 0
    runs = []
    x = 0
    while x < len(cols):
        if cols[x]:
            x0 = x
            while x < len(cols) and cols[x]:
                x += 1
            if runs and x0 - runs[-1][1] < 4:
                runs[-1][1] = x
            else:
                runs.append([x0, x])
        else:
            x += 1
    runs = [r for r in runs if r[1] - r[0] >= 12]
    al = (np.array(im)[..., 3] > 0).sum(axis=0)
    while len(runs) < count:   # 붙어 버린 것 - 가장 넓은 덩어리를 가운데 근처의 가장 가는 곳에서 가른다
        k = max(range(len(runs)), key=lambda i: runs[i][1] - runs[i][0])
        x0, x1 = runs[k]
        lo = x0 + (x1 - x0) * 3 // 10
        hi = x0 + (x1 - x0) * 7 // 10
        cut = lo + int(np.argmin(al[lo:hi]))
        runs[k:k + 1] = [[x0, cut], [cut, x1]]
    if len(runs) != count:
        print("  !! %s: %d runs (expected %d)" % (path, len(runs), count))
    out = []
    for x0, x1 in runs:
        c = im.crop((x0, 0, x1, im.height))
        out.append(c.crop(c.getbbox()))
    return out


n = 0
SHEETS = {
    "bg_bun_top": ["bun_sesame_top", "bun_brioche_top", "bun_potato_top", "bun_ink_top", "bun_lettuce_top", "bun_muffin_top"],
    "bg_bun_bot": ["bun_sesame_bot", "bun_brioche_bot", "bun_potato_bot", "bun_ink_bot", "bun_lettuce_bot", "bun_muffin_bot"],
    "bg_patty": ["pt_beef", "pt_chicken", "pt_pork", "pt_shrimp", "pt_vegan"],
    "bg_veg": ["vg_lettuce", "vg_tomato", "vg_onion", "vg_pickle", "vg_jalapeno", "vg_avocado", "vg_mushroom"],
    "bg_cheese": ["ch_cheddar", "ch_swiss", "ch_mozza", "ch_pepper", "ch_blue"],
    "bg_topping": ["tp_bacon", "tp_egg", "tp_hash", "tp_pork", "tp_chili"],
    "bg_props": ["sauce", "bottle", "cola", "fries", "coin", "steam", "star"],
    "bg_tools": ["tool_griddle", "tool_board", "tool_trash", "tool_register", "tool_drink", "tool_fryer"],
    "bg_sides": ["dr_cola", "dr_fanta", "dr_cider", "dr_oj", "cup", "_", "_", "_", "_", "_"],   # 뒤 다섯(찍는 소스 컵)은 안 쓴다 - 가루 양념 통으로 바꿨다
    "bg_cats": ["cat_0", "cat_1", "cat_2", "cat_3", "cat_4", "cat_5"],
    "bg_wrap": ["wrap_stack", "wrap_sleeve", "bag", "knife"],
    "bg_shakers": ["dp_salt", "dp_cheese", "dp_onion", "dp_chili", "dp_honey"],
    "bg_fryparts": ["fry_raw", "fry_good", "fry_burnt"],
}
for sheet, names in SHEETS.items():
    f = latest(sheet)
    if not f:
        continue
    big = 320 if sheet == "bg_tools" else 256
    for name, im in zip(names, row_split(f, len(names))):
        if name == "_":
            continue
        k = float(big) / max(im.size)
        im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS).save(OUT + "bg_%s.png" % name)
        n += 1
f = latest("bg_machine")   # 음료 기계 한 장(칸 넷 — 자리는 main._tap_rect 가 그림 비율로 잡는다)
if f:
    im = keyed(f)
    im = im.crop(im.getbbox())
    k = 420.0 / max(im.size)
    im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS).save(OUT + "bg_tool_machine.png")
    n += 1
for c in range(6):
    f = latest("bg2_cust_%d" % c) or latest("bg_cust_%d" % c)   # 11-11 몸통까지 그린 손님(카운터에 허리가 가린다)이 있으면 그것
    if not f:
        continue
    # 같은 폭 넷으로 자른다 - 반짝이 · 땀방울이 몸에서 떨어져 있어 틈으로 나누면 조각난다
    whole = keyed(f)
    cw = whole.width // 4
    fr = []
    for e in range(4):
        c4 = whole.crop((e * cw, 0, (e + 1) * cw, whole.height))
        fr.append(c4.crop(c4.getbbox()))
    W = max(i.width for i in fr)
    H = max(i.height for i in fr)
    for e, im in enumerate(fr):   # 같은 틀에 — 아래(카운터에 얹은 손)를 맞춘다
        cv = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cv.paste(im, ((W - im.width) // 2, H - im.height))
        cv.resize((max(1, W * 256 // H), 256), Image.LANCZOS).save(OUT + "bg_cust_%d_%d.png" % (c, e))
        n += 1


def cover(path, w, h):
    im = Image.open(path).convert("RGB")
    k = max(float(w) / im.width, float(h) / im.height)
    im = im.resize((int(im.width * k + 0.5), int(im.height * k + 0.5)), Image.LANCZOS)
    x = (im.width - w) // 2
    y = (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


for d in range(3):
    f = latest("bg_shop_%d" % d)
    if f:
        cover(f, 1280, 720).save(OUT + "bg_shop_%d.png" % d)
        n += 1
f = latest("bg_mock")
if f:
    cover(f, 1280, 720).save(OUT + "bg_title.png")
    im = Image.open(f).convert("RGB")
    s = im.height
    im.crop(((im.width - s) // 2, 0, (im.width - s) // 2 + s, s)).resize((512, 512), Image.LANCZOS).save(OUT + "bg_card.png")
    n += 2
print("put", n)
if len(sys.argv) > 1:   # 확인용 모음
    fs = sorted(glob.glob(OUT + "bg_*.png"))
    fs = [f for f in fs if "shop" not in f and "title" not in f and "card" not in f]
    cols = 10
    W = Image.new("RGBA", (cols * 130, ((len(fs) + cols - 1) // cols) * 130), (60, 64, 72, 255))
    for k, f in enumerate(fs):
        im = Image.open(f).convert("RGBA")
        im.thumbnail((124, 124))
        W.paste(im, ((k % cols) * 130 + 3, (k // cols) * 130 + 3), im)
    W.save(sys.argv[1])


# 가게 단계 배경(11-11) — art/source/bg2_room_N_g*_01.png(가장 최근) → art/burger/bg_room_N.png(폭 1280, 비율 그대로)
for _n in range(4):
    _fs = sorted(glob.glob("art/source/bg2_room_%d_g*_01.png" % _n))
    if _fs:
        _im = Image.open(_fs[-1]).convert("RGB")
        _im.resize((1280, int(_im.height * 1280 / _im.width)), Image.LANCZOS).save("art/burger/bg_room_%d.png" % _n)
