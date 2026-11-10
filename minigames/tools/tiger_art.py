# "떡 하나 주면 안 잡아먹지" 그림 넣기 — art/source 의 GPT 후보(tg_*_g<월일>_*.png, 가장 최근 것)를 잘라 art/tiger/ 에.
#   <sprite-gen venv>/python -I tools/tiger_art.py      (Pillow · numpy 필요)   그다음 lossy_big.gd · --import
# 물건 · 호랑이 = 마젠타 바탕을 빼고 테두리에 맞춰 자름. 달리기 네 칸은 같은 배율로 줄여 같은 크기 판에 발을 아래로 맞춘다.
# 배경 띠 = 위쪽 하늘(한 가지 색)을 위 가장자리에서 번져 가며 뺀다(멀리 · 가까이 띠가 겹쳐 보이게).
import glob
import numpy as np
from PIL import Image, ImageDraw


def latest(n):
    fs = sorted(glob.glob("art/source/%s_g*_01.png" % n))
    return fs[-1] if fs else None


def keyed(path):
    a = np.array(Image.open(path).convert("RGBA")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    key = (r > 170) & (b > 170) & (g < 110) & (abs(r - b) < 70)
    a[..., 3] = np.where(key, 0, 255)
    spill = (~key) & (r > 150) & (b > 150) & (g < 140)   # 테두리에 남은 분홍 기운
    a[..., 0] = np.where(spill, g, r)
    a[..., 2] = np.where(spill, g, b)
    im = Image.fromarray(a.astype("uint8"), "RGBA")
    return im.crop(im.getbbox())


OBJ = {"tg_tiger_run": 320, "tg_tiger_jump": 320, "tg_tiger_slide": 320, "tg_obs_rock": 256, "tg_obs_stump": 256, "tg_obs_branch": 384,
       "tg_obs_gotgam": 384, "tg_tteok": 128, "tg_kkochi": 256, "tg_gotgam_ghost": 384, "tg_item_honey": 160, "tg_item_sansam": 160,
       "tg_item_club": 160, "tg_item_rope": 384, "tg_plank": 512}
n = 0
for name, mx in OBJ.items():
    f = latest(name)
    if f is None:
        continue
    im = keyed(f)
    if name == "tg_kkochi" and im.width > im.height:
        im = im.rotate(90, expand=True)
    im.thumbnail((mx, mx), Image.LANCZOS)
    im.save("art/tiger/%s.png" % name)
    n += 1
fr = [keyed(latest("tg_tiger_run_%d" % k)) for k in range(4) if latest("tg_tiger_run_%d" % k)]
if len(fr) == 4:
    k = 300.0 / max(f.height for f in fr)   # 치비는 키가 기준(네 칸의 키가 같아야 달릴 때 크기가 안 출렁인다)
    fr = [f.resize((int(f.width * k), int(f.height * k)), Image.LANCZOS) for f in fr]
    W = max(f.width for f in fr)
    H = max(f.height for f in fr)
    for i, f in enumerate(fr):
        c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        c.paste(f, ((W - f.width) // 2, H - f.height))
        c.save("art/tiger/tg_tiger_run_%d.png" % i)
        n += 1
for t in range(4):
    for lay in ["far", "near"]:
        name = "tg_bg_%d_%s" % (t, lay)
        f = latest(name)
        if f is None:
            continue
        im = Image.open(f).convert("RGBA")
        w, h = im.size
        rgb = im.convert("RGB")
        for x in range(0, w, 16):
            if rgb.getpixel((x, 0)) != (255, 0, 255):
                ImageDraw.floodfill(rgb, (x, 0), (255, 0, 255), thresh=38)
        a = np.array(im)
        m = np.array(rgb)
        sky = (m[..., 0] == 255) & (m[..., 1] == 0) & (m[..., 2] == 255)
        a[..., 3] = np.where(sky, 0, 255)
        im = Image.fromarray(a, "RGBA")
        bb = im.getbbox()
        im = im.crop((0, bb[1], w, bb[3]))
        im.resize((1024, max(1, int(im.height * 1024 / w))), Image.LANCZOS).save("art/tiger/%s.png" % name)
        n += 1
f = latest("tg_bg_title")
if f:
    im = Image.open(f).convert("RGB")
    im.resize((1024, int(im.height * 1024 / im.width)), Image.LANCZOS).save("art/tiger/tg_bg_title.png")
    n += 1
f = latest("tg_card")
if f:
    im = Image.open(f).convert("RGB")
    s = min(im.size)
    im.crop(((im.width - s) // 2, (im.height - s) // 2, (im.width + s) // 2, (im.height + s) // 2)).resize((512, 512), Image.LANCZOS).save("art/tiger/tg_card.png")
    n += 1
print("put", n)
# 땅 띠(tg_ground_N) — 언덕 · 산을 따라 휘어 그리는 풀 + 흙. 폭 1024 로 줄이고, 풀 윗선(가로로 꽉 찬 첫 줄)이 위에서 40px 에 오게 자르고,
# 왼쪽 끝 48px 를 오른쪽 끝과 섞어 이음매를 없앤다. 맨 아랫줄의 평균 색을 찍는다 — TgD.SOIL 에 적는다(그 밑을 채우는 색).
for t in range(4):
    f = latest("tg_ground_%d" % t)
    if f is None:
        continue
    a = np.array(Image.open(f).convert("RGBA")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    key = (r > 170) & (b > 170) & (g < 110) & (abs(r - b) < 70)
    a[..., 3] = np.where(key, 0, 255)
    im = Image.fromarray(a.astype("uint8"), "RGBA")
    im = im.resize((1024, im.height * 1024 // im.width), Image.LANCZOS)
    a = np.array(im).astype(float)
    full = np.where((a[..., 3] > 128).mean(axis=1) > 0.97)[0]
    surf = int(full[0])
    a = a[max(0, surf - 40):]
    if surf < 40:
        a = np.concatenate([np.zeros((40 - surf, 1024, 4)), a])
    B = 48
    k = (np.arange(B) / float(B))[None, :, None]
    a[:, :B] = a[:, -B:] * (1.0 - k) + a[:, :B] * k
    a = a[:, :-B]
    Image.fromarray(a.astype("uint8"), "RGBA").resize((1024, a.shape[0]), Image.LANCZOS).save("art/tiger/tg_ground_%d.png" % t)
    print("ground", t, a.shape[0], [int(v) for v in a[-2, :, :3].mean(axis=0)])
