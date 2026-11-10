#!/usr/bin/env python3
"""art/source 의 AI 후보를 붉은 별 · 잿빛 요새가 읽는 크기 · 모양으로 잘라 넣는다(임시 그림 tools/temp_art.py 와 같은 이름 · 크기).

    python tools/apply_art.py          # minigames/ 에서. 넣은 이름은 art/TEMP_ART.txt 에서 지운다(임시 그림이 다시 덮지 않게)
    godot --headless --path . --script res://tools/lossy_big.gd ; godot --headless --path . --import

post.gd 의 plain 은 정사각형 그대로 넣어서 화면(16:9) · 카드 그림 칸(3:2) · 둥근 말에 맞지 않는다. 여기서 자른다.
  카드 rs_c_N    1024² → 아래쪽 3:2 띠(하늘을 덜고, 맨 아래 가짜 서명 줄을 잘라 냄) → 384×256
  초상 ak_h/m_N  종이 테두리를 잘라 내고 원으로 → 256×256 (말이 동그라미라 네모로 넣으면 모서리가 삐져나온다)
  배경           16:9 로 → 1024×576
SKIP 은 눈으로 보고 뺀 것(이유를 적는다) — 그 이름은 임시 그림이 남는다. 다시 뽑아 마음에 들면 SKIP · BOX 에서 그 이름을 지우고 돌린다
(후보가 여럿이면 이름순 마지막 것을 쓴다 — 고른 것만 남기거나 고른 파일을 가장 늦은 이름으로 둔다).
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "source")

SKIP = {
    "rs_bg_board": "화성 판 바탕인데 유럽 지도와 가짜 글씨 · 서명이 든 포스터로 나왔다",
}
# 초상마다 자를 네모(가로 0~1, 세로 0~1). 기본은 종이 테두리만 벗긴다.
BOX = {
    "ak_h_3": (0.25, 0.22, 0.75, 0.72),    # 인물이 작게 나와서 당겨 자른다
    "ak_m_7": (0.20, 0.20, 0.80, 0.80),    # 양옆 붉은 띠를 뺀다
    "ak_m_8": (0.27, 0.50, 0.73, 0.96),    # 봉인석 — 사람이 아니라 사슬 감긴 돌 쪽
}


def pick(name):
    # Cloudflare(_1110_…jpg) 와 GPT(gen_gpt.sh, _g1110_…png) 후보 둘 다 — 가장 뒤(최근) 것
    c = sorted(glob.glob(os.path.join(SRC, name + "_1[0-9][0-9][0-9]_*_*.jpg")) + glob.glob(os.path.join(SRC, name + "_g[0-9][0-9][0-9][0-9]_*_*.png")))
    return c[-1] if c else None


def band(im, ratio, y_center):
    w, h = im.size
    bh = int(w / ratio)
    y0 = max(0, min(h - bh, int(h * y_center - bh / 2)))
    return im.crop((0, y0, w, y0 + bh))


def main():
    done = []
    names = ["rs_c_%d" % i for i in range(80)] + ["rs_bg_title", "rs_bg_board", "rs_card"]
    names += ["ak_h_%d" % i for i in range(4)] + ["ak_m_%d" % i for i in range(11)] + ["ak_bg_title", "ak_bg_board", "ak_card"]
    names += ["ak_c_%d_%d" % (h, k) for h in range(4) for k in range(12)]   # 행동 카드 삽화 — 가운데 띠 3:1
    for name in names:
        if name in SKIP:
            print("건너뜀", name, "-", SKIP[name])
            continue
        src = pick(name)
        if src is None:
            continue
        im = Image.open(src).convert("RGB")
        game = "redstar" if name.startswith("rs_") else "ashkeep"
        if name.startswith("ak_c_"):
            out = band(im, 3.0, 0.5).resize((384, 128), Image.LANCZOS)
        elif name.startswith("rs_c_"):
            out = band(im, 1.5, 0.58).resize((384, 256), Image.LANCZOS)
        elif "_bg_" in name:
            out = band(im, 16 / 9, 0.55 if name != "ak_bg_title" else 0.62).resize((1024, 576), Image.LANCZOS)
        elif name.endswith("_card"):
            w, h = im.size
            out = im.crop((int(w * 0.1), int(h * 0.1), int(w * 0.9), int(h * 0.9))).resize((512, 512), Image.LANCZOS)
        else:
            x0, y0, x1, y1 = BOX.get(name, (0.10, 0.10, 0.90, 0.90))
            w, h = im.size
            sq = im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1))).resize((512, 512), Image.LANCZOS)
            mask = Image.new("L", (512, 512), 0)
            ImageDraw.Draw(mask).ellipse((2, 2, 509, 509), fill=255)
            out = sq.convert("RGBA")
            out.putalpha(mask)
            out = out.resize((256, 256), Image.LANCZOS)
        out.save(os.path.join(ROOT, "art", game, name + ".png"))
        done.append(game + "/" + name)
    # 넣은 이름은 임시 목록에서 뺀다
    lst = os.path.join(ROOT, "art", "TEMP_ART.txt")
    if os.path.exists(lst):
        with open(lst, encoding="utf-8") as f:
            lines = f.read().splitlines()
        keep = [ln for ln in lines if ln.strip() not in done]
        with open(lst, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(keep) + "\n")
    print("넣음", len(done))
    return 0


if __name__ == "__main__":
    sys.exit(main())
