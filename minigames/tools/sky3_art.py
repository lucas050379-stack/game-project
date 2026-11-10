# 스카이 어설트 3차 그림 넣기(11-10) — art/source 의 GPT 그림(가장 최근 것)을 art/sky/ 에.
#   <sprite-gen venv>/python -I tools/sky3_art.py     (minigames/ 에서. Pillow · numpy)   그다음 lossy_big.gd · --import
# 기체 일곱(sky4_craft_N → sky_craft_N) · 서브기체(sky4_optN → sky_option_N) · 봄의 아군기(sky4_ally_* → sky3_ally_*) ·
# (sky3_* = 새 디자인의 첫 그림, sky4_* = 그것을 참조로 굵은 픽셀풍으로 다시 그린 것 — 게임에는 sky4 가 들어간다)
# 봄 그림 넷(sky3_bomb_* → sky_bomb_*) · 아군 탄 다섯(sky3_shot_* → sky_shot_*) · 표적 화면 포스터(sky_poster_N).
import glob
import sys
import numpy as np
from PIL import Image


def latest(n):
    fs = sorted(glob.glob("art/source/%s_g*_01.png" % n))
    return fs[-1] if fs else None


def keyed(path, crop=True):
    a = np.array(Image.open(path).convert("RGBA")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    key = (r > 170) & (b > 170) & (g < 110) & (abs(r - b) < 70)
    a[..., 3] = np.where(key, 0, 255)
    spill = (~key) & (r > g + 60) & (b > g + 60)   # 테두리에 남은 분홍 기운
    avg = (g + np.minimum(r, b)) // 2
    a[..., 0] = np.where(spill, avg, r)
    a[..., 2] = np.where(spill, avg, b)
    im = Image.fromarray(a.astype("uint8"), "RGBA")
    return im.crop(im.getbbox()) if crop else im


def square(im, size):
    s = max(im.size)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.paste(im, ((s - im.width) // 2, (s - im.height) // 2))
    return sq.resize((size, size), Image.LANCZOS)


n = 0
for i in range(7):
    for src, dst in [("sky4_craft_%d" % i, "sky_craft_%d" % i), ("sky4_opt%d" % i, "sky_option_%d" % i)]:
        f = latest(src)
        if f:
            square(keyed(f), 256).save("art/sky/%s.png" % dst)
            n += 1
for src, size in [("sky3_ally_bomber", 256), ("sky3_ally_big", 512)]:
    f = latest(src.replace("sky3_", "sky4_"))   # sky4 = 같은 그림을 굵은 픽셀풍으로 다시 그린 것(매끈한 sky3 는 "애니풍"이라는 지적)
    if f:
        square(keyed(f), size).save("art/sky/%s.png" % src)
        n += 1
f = latest("sky3_bomb_napalm")
if f:
    im = keyed(f)
    im.resize((512, im.height * 512 // im.width), Image.LANCZOS).save("art/sky/sky_bomb_napalm.png")
    n += 1
f = latest("sky3_bomb_storm")
if f:
    im = keyed(f)
    im.resize((im.width * 512 // im.height, 512), Image.LANCZOS).save("art/sky/sky_bomb_storm.png")
    n += 1
f = latest("sky3_bomb_cluster")
if f:
    square(keyed(f), 384).save("art/sky/sky_bomb_cluster.png")
    n += 1
# 포탄 — 코드가 "머리가 위"인 그림을 뒤집어 쓴다(새 그림은 머리가 아래로 왔다 → 위아래를 뒤집어 넣는다)
f = latest("sky3_bomb_barrage")
if f:
    square(keyed(f).transpose(Image.FLIP_TOP_BOTTOM), 128).save("art/sky/sky_bomb_barrage.png")
    n += 1
# 아군 탄 — **흰색 밝기 그림**으로 넣는다(코드가 기체 색을 곱한다). 방향은 옛 그림과 같게: 레이저는 세로(새 그림은 45도 누웠다 → 돌린다),
# 다트는 촉이 아래, 초승달은 볼록한 쪽이 왼쪽 아래, 미사일은 오른쪽 위.
for name in ["laser", "dart", "star", "crescent", "missile"]:
    f = latest("sky3_shot_" + name)
    if not f:
        continue
    im = keyed(f, False)
    if name == "laser":
        im = im.rotate(45, resample=Image.BICUBIC, expand=True)
    im = im.crop(im.getbbox())
    a = np.array(im).astype(float)
    lum = a[..., :3].max(axis=2)
    lum = np.clip(lum * 255.0 / max(1.0, lum.max()), 0, 255)
    a[..., 0] = a[..., 1] = a[..., 2] = lum
    square(Image.fromarray(a.astype("uint8"), "RGBA"), 128).save("art/sky/sky_shot_%s.png" % name)
    n += 1
for i in range(1, 7):
    f = latest("sky_poster_%d" % i)
    if f:
        im = Image.open(f).convert("RGB")
        im.resize((1280, im.height * 1280 // im.width), Image.LANCZOS).save("art/sky/sky_poster_%d.png" % i)
        n += 1


# 한 줄 시트(sky5_*) — 열마다 비어 있는 틈으로 나눈다. 탄 일곱(주황 불빛 — 코드가 기체 색으로 색상을 돌린다) · 불줄기 네 칸 · 번개 네 장.
def row_split(path, count):
    im = keyed(path, False)
    al = np.array(im)[..., 3] > 0
    cols = al.sum(axis=0) > 0
    runs = []
    x = 0
    while x < len(cols):
        if cols[x]:
            x0 = x
            while x < len(cols) and cols[x]:
                x += 1
            if runs and x0 - runs[-1][1] < 10:   # 좁은 틈은 한 덩어리(빛 번짐이 끊긴 것)
                runs[-1][1] = x
            else:
                runs.append([x0, x])
        else:
            x += 1
    runs = [r for r in runs if r[1] - r[0] >= 6]
    if len(runs) != count:
        print("  !! %s: %d runs (expected %d)" % (path, len(runs), count))
    out = []
    for x0, x1 in runs:
        c = im.crop((x0, 0, x1, im.height))
        out.append(c.crop(c.getbbox()))
    return out


f = latest("sky5_bullets")
if f:
    for name, im in zip(["laser", "cannon", "dart", "star", "moon", "needle", "missile"], row_split(f, 7)):
        square(im, 96).save("art/sky/sky_bul_%s.png" % name)
        n += 1
# 네온 탄(sky7_neo_<종류>) — 검은 바탕에 빛나는 탄 여섯 단계 한 줄. 검정을 투명으로: 알파 = 밝기(빛 번짐이 그대로 반투명이 된다), 색은 그만큼 되돌린다.
# 가장 큰 단계의 긴 변을 128 로 맞추고 작은 단계는 같은 비율로 — 단계마다 정사각 한 장(sky_neo_<종류>_0..5).
def glow_split(path, count, even=False):
    a = np.array(Image.open(path).convert("RGB")).astype(float)
    mx = a.max(axis=2)
    al = np.clip((mx - 14.0) / 150.0, 0.0, 1.0)            # 14 아래는 바탕의 잡티
    rgb = np.clip(a / np.maximum(mx, 1.0)[..., None] * np.maximum(mx, 150.0)[..., None], 0, 255)
    im = Image.fromarray(np.dstack([rgb, al * 255.0]).astype("uint8"), "RGBA")
    if even:   # 흐린 그림(기운 첫 단계)은 덩어리로 못 나눈다 - 같은 폭으로 자른다
        cw = im.width // count
        cells = [im.crop((i * cw, 0, (i + 1) * cw, im.height)) for i in range(count)]
        return [c.crop(c.getbbox() or (0, 0, 8, 8)) for c in cells]
    solid = al > 0.25
    cols = solid.sum(axis=0) > 0
    runs = []
    x = 0
    while x < len(cols):
        if cols[x]:
            x0 = x
            while x < len(cols) and cols[x]:
                x += 1
            if runs and x0 - runs[-1][1] < 14:
                runs[-1][1] = x
            else:
                runs.append([x0, x])
        else:
            x += 1
    runs = [r for r in runs if r[1] - r[0] >= 8]
    if len(runs) != count:
        print("  !! %s: %d runs (expected %d)" % (path, len(runs), count))
    out = []
    for i, (x0, x1) in enumerate(runs):
        l = (runs[i - 1][1] + x0) // 2 if i > 0 else max(0, x0 - 30)       # 빛 번짐까지 — 옆 덩어리와의 한가운데까지
        r = (x1 + runs[i + 1][0]) // 2 if i + 1 < len(runs) else min(im.width, x1 + 30)
        c = im.crop((l, 0, r, im.height))
        out.append(c.crop(c.getbbox()))
    return out


for name in ["laser", "cannon", "dart", "star", "moon", "needle", "missile", "homing"]:
    f = latest("sky7_neo_" + name)
    if not f:
        continue
    fr = glow_split(f, 6)[:6]
    k = 128.0 / max(max(i.size) for i in fr)
    for j, im in enumerate(fr):
        side = max(8, int(round(max(im.size) * k)))
        im = im.resize((max(1, int(round(im.width * k))), max(1, int(round(im.height * k)))), Image.LANCZOS)
        c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        c.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
        c.save("art/sky/sky_neo_%s_%d.png" % (name, j))
        n += 1
# 그림 기둥(sky7_beam_*) — 세로로 이어 붙는 기둥 네 칸. 높이 256 으로.
for name in ["bolt", "plasma", "rope"]:
    f = latest("sky7_beam_" + name)
    if not f:
        continue
    fr = glow_split(f, 4)[:4]
    W = min(i.width for i in fr)
    H = min(i.height for i in fr)
    for j, im in enumerate(fr):   # 같은 크기로 — 가운데를 잘라 맞춘다
        im = im.crop(((im.width - W) // 2, (im.height - H) // 2, (im.width - W) // 2 + W, (im.height - H) // 2 + H))
        # 위아래 이음매 - 위쪽 띠를 아래 끝과 섞고 그만큼 잘라 낸다(이어 붙일 때 가로줄이 보였다)
        arr = np.array(im).astype(float)
        B = max(8, arr.shape[0] // 8)
        kk = (np.arange(B) / float(B))[:, None, None]
        arr[:B] = arr[-B:] * (1.0 - kk) + arr[:B] * kk
        im = Image.fromarray(arr[:-B].astype("uint8"), "RGBA")
        im.resize((max(8, im.width * 256 // im.height), 256), Image.LANCZOS).save("art/sky/sky_beam_%s_%d.png" % (name, j))
        n += 1
# 스킬 기운 여섯 단계(sky8_charge → sky_charge_0..5, 정사각 160) · 지원기 방벽 네 칸(sky8_shield → sky_shield_0..3, 폭 384)
f = latest("sky8_charge")
if f:
    fr = glow_split(f, 6, True)
    side = max(max(i.size) for i in fr)
    for j, im in enumerate(fr):
        c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        c.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
        c.resize((160, 160), Image.LANCZOS).save("art/sky/sky_charge_%d.png" % j)
        n += 1
f = latest("sky8_shield")
if f:
    fr = glow_split(f, 4)[:4]
    W = max(i.width for i in fr)
    H = max(i.height for i in fr)
    for j, im in enumerate(fr):
        c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        c.paste(im, ((W - im.width) // 2, (H - im.height) // 2))
        c.resize((384, max(8, H * 384 // W)), Image.LANCZOS).save("art/sky/sky_shield_%d.png" % j)
        n += 1
# 원자 폭탄(커세어) - 폭격기 · 폭탄(자홍 바탕) · 폭발 네 단계(검은 바탕, 같은 틀)
for src, dst, size in [("sky9_nuke_bomber", "sky_nuke_bomber", 384), ("sky9_nuke_bomb", "sky_nuke_bomb", 128)]:
    f = latest(src)
    if f:
        square(keyed(f), size).save("art/sky/%s.png" % dst)
        n += 1
f = latest("sky9_nuke_blast")
if f:
    fr = glow_split(f, 4)[:4]
    side = max(max(i.size) for i in fr)
    for j, im in enumerate(fr):
        c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        c.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
        c.resize((384, 384), Image.LANCZOS).save("art/sky/sky_nuke_%d.png" % j)
        n += 1
# 탄 네 칸(sky6_bul_<종류>) — 같은 틀 · 같은 중심에 맞춰 sky_bul_<종류>_0..3 으로
for name in ["laser", "cannon", "dart", "star", "moon", "needle", "missile"]:
    f = latest("sky6_bul_" + name)
    if not f:
        continue
    fr = row_split(f, 4)[:4]
    side = max(max(i.size) for i in fr)
    for k, im in enumerate(fr):
        c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        # 미사일은 불꽃 길이가 칸마다 달라 위(머리)를 맞춘다 — 가운데를 맞추면 몸이 위아래로 떤다
        c.paste(im, ((side - im.width) // 2, 0 if name == "missile" else (side - im.height) // 2))
        c.resize((96, 96), Image.LANCZOS).save("art/sky/sky_bul_%s_%d.png" % (name, k))
        n += 1
for src, dst, hh, bottom in [("sky5_flame", "sky_flame", 384, True), ("sky5_bolt", "sky_bolt", 512, False)]:
    f = latest(src)
    if not f:
        continue
    fr = row_split(f, 4)
    W = max(i.width for i in fr)
    H = max(i.height for i in fr)
    for k, im in enumerate(fr):   # 같은 틀에 — 불줄기는 아래(노즐)를, 번개는 위를 맞춘다
        c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        c.paste(im, ((W - im.width) // 2, H - im.height if bottom else 0))
        c.resize((W * hh // H, hh), Image.LANCZOS).save("art/sky/%s_%d.png" % (dst, k))
        n += 1
print("put", n)
if len(sys.argv) > 1:   # 확인용 모음
    names = ["sky_craft_%d" % i for i in range(7)] + ["sky_option_%d" % i for i in range(7)] + ["sky3_ally_bomber", "sky3_ally_big", "sky_bomb_napalm", "sky_bomb_storm",
            "sky_bomb_cluster", "sky_bomb_barrage", "sky_shot_laser", "sky_shot_dart", "sky_shot_star", "sky_shot_crescent", "sky_shot_missile"]
    W = Image.new("RGBA", (7 * 200, 4 * 200), (50, 54, 62, 255))
    for k, nm in enumerate(names):
        try:
            im = Image.open("art/sky/%s.png" % nm).convert("RGBA")
        except OSError:
            continue
        im.thumbnail((190, 190))
        W.paste(im, ((k % 7) * 200 + 5, (k // 7) * 200 + 5), im)
    W.save(sys.argv[1])
