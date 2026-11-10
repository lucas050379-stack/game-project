# 떡 하나 — Cloudflare(flux-schnell)로 뽑은 그림 넣기(11-10 밤, GPT 사용량 제한 동안 임시로).
#   <sprite-gen venv>/python -I tools/tiger_cf.py   그다음 lossy_big.gd · --import
# 배경: flux 는 마젠타 바탕 띠를 못 그린다(땅까지 있는 풍경 한 장이 나온다) → 한 장을 아래쪽 땅을 잘라 내고
#   좌우로 뒤집어 이어 붙여(이음매 없음) 테마마다 한 겹짜리 배경(tg_back_N)으로 쓴다. 있으면 art.gd 가 예전 두 겹 띠 대신 그린다.
# 물건: 분홍 바탕을 모서리 색과의 거리로 뺀다.
import glob
import numpy as np
from PIL import Image, ImageOps


def pick(name, i):
    return sorted(glob.glob("art/source/%s_1110_2*.jpg" % name))[i]


# 테마: (이름, 몇 번째 후보, 위에서부터 남길 비율)
BACK = [("tg_bg_0_near", 1, 0.71), ("tg_bg_1_far", 1, 0.90), ("tg_bg_2_near", 0, 0.80), ("tg_bg_3_far", 0, 0.85)]
for t, (name, i, frac) in enumerate(BACK):
    im = Image.open(pick(name, i)).convert("RGB")
    im = im.crop((0, 0, im.width, int(im.height * frac)))
    h = 512
    im = im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
    out = Image.new("RGB", (im.width * 2, h))
    out.paste(im, (0, 0))
    out.paste(ImageOps.mirror(im), (im.width, 0))
    out.save("art/tiger/tg_back_%d.png" % t)

OBJ = [("tg_obs_burr", "tg_obs_burr", 1, 192), ("tg_obs_millstone", "tg_obs_millstone", 1, 320), ("tg_obs_axe", "tg_cf_axe", 0, 384), ("tg_obs_bolt", "tg_cf_bolt", 1, 192)]
for out, name, i, mx in OBJ:
    a = np.array(Image.open(pick(name, i)).convert("RGBA")).astype(int)
    key = a[2:10, 2:10, :3].reshape(-1, 3).mean(axis=0)
    d = np.sqrt(((a[..., :3] - key) ** 2).sum(axis=2))
    pink = (a[..., 0] > 170) & (a[..., 2] > a[..., 1] + 40) & (a[..., 0] > a[..., 1] + 90)   # 그림자 · 바탕의 얼룩도 분홍 계열
    a[..., 3] = np.where((d < 70) | pink, 0, 255)
    im = Image.fromarray(a.astype("uint8"), "RGBA")
    im = im.crop(im.getbbox())
    im.thumbnail((mx, mx), Image.LANCZOS)
    im.save("art/tiger/%s.png" % out)
print("ok")
