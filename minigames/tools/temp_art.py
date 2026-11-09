#!/usr/bin/env python3
"""임시 그림 — AI 그림을 뽑기 전까지 자리를 채우는 단순한 그림을 코드로 만든다(사용자 요청 11-09: "그림 생성은 추후 AI 로, 임시 이미지를").

    pip install pillow
    python tools/temp_art.py               # minigames/ 에서. art/redstar · art/ashkeep 에 쓴다
    godot --headless --path . --import

**여기서 만든 파일은 전부 임시다.** 이름이 `art/prompts.txt` 의 것과 같아서(rs_c_N · rs_bg_* · ak_h_N · ak_m_N · ak_bg_*),
AI 그림을 같은 이름으로 넣으면 그대로 바뀐다. 이미 진짜 그림이 들어간 이름은 건드리지 않게, **이 스크립트는 `art/TEMP_ART.txt` 에 적힌
이름만 다시 쓴다**(처음 돌릴 때 만든 목록 — 진짜 그림으로 바꾼 이름은 그 목록에서 지울 것).
크기는 긴 변 512 미만(ADR-0011 의 무손실 쪽)으로 작게 둔다.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
LIST = os.path.join(ROOT, "art", "TEMP_ART.txt")
SS = 2   # 크게 그려서 줄인다(계단 현상 줄이기)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(w, h, top, bot):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(top, bot, y / max(1, h - 1)))
    return im


def ridge(d, w, y0, amp, col, rng, step=40):
    pts = [(0, y0 + rng.uniform(-amp, amp))]
    x = 0
    while x < w:
        x += rng.uniform(step * 0.6, step * 1.4)
        pts.append((x, y0 + rng.uniform(-amp, amp)))
    d.polygon(pts + [(w, 9999), (0, 9999)], fill=col)


# ==================== 붉은 별 개척단 — 카드 80 · 배경 2 ====================

# data.gd 의 CARDS 와 같은 순서: (종류 0 건설 · 1 운영 · 2 사건, 태그들, 덧붙임)
RS_CARDS = [
    (0, [0], ""), (0, [3, 0], ""), (0, [1, 5], ""), (0, [1], "ocean"), (0, [6, 0], ""), (0, [3], ""), (0, [2], "cloud"), (0, [0], ""),
    (0, [0, 2], ""), (0, [5, 0], "wind"), (0, [0, 5], "heat"), (0, [5], "solar"), (0, [6], ""), (0, [6, 0], ""), (0, [3], "ocean"),
    (0, [3], "trees"), (0, [3, 0], ""), (0, [1], ""), (0, [1], ""), (0, [0, 2], "cloud"), (0, [0], "heat"), (0, [2, 0], ""), (0, [2, 4], ""),
    (0, [6], "ocean"), (0, [5, 0], "solar"), (0, [0], ""), (0, [1, 0], ""), (0, [2, 0], "heat"), (0, [5, 0], "heat"), (0, [4], ""),
    (0, [3], "trees"), (0, [1, 2], ""), (0, [6, 0], "ice"), (0, [4, 3], ""), (0, [5, 0], "ocean"), (0, [0], "heat"), (0, [6, 0, 2], ""),
    (0, [3], "trees"), (0, [2, 3, 4], ""), (0, [0], "ocean"),
    (1, [4, 2], ""), (1, [0, 2], ""), (1, [1], ""), (1, [2], ""), (1, [0, 2], "cloud"), (1, [5, 0], "heat"), (1, [3, 0], ""), (1, [1], ""),
    (1, [2], ""), (1, [4], ""), (1, [0], ""), (1, [1, 0], ""), (1, [2], ""), (1, [2, 4], ""), (1, [5], "solar"), (1, [2], "cloud"),
    (1, [3, 0], "trees"), (1, [6], ""), (1, [3], "trees"), (1, [4], ""),
    (2, [1], "meteor"), (2, [0], "burst"), (2, [], "burst"), (2, [2, 1], ""), (2, [1], "meteor"), (2, [1], "meteor ocean"), (2, [3], "trees"),
    (2, [], "burst heat"), (2, [], ""), (2, [2], ""), (2, [], "cloud"), (2, [3], ""), (2, [], ""), (2, [], "ocean"), (2, [0], ""),
    (2, [1], "meteor"), (2, [], "burst"), (2, [2], ""), (2, [1], "burst"), (2, [], ""),
]

RUST = (158, 76, 48)
RUST_D = (104, 46, 34)
RUST_L = (200, 112, 70)
INK = (40, 22, 22)


def rs_card(idx, kind, tags, extra, w=384, h=256):
    rng = random.Random(1000 + idx)
    W, H = w * SS, h * SS
    space = 1 in tags
    event = kind == 2
    if space:
        im = gradient(W, H, (14, 12, 26), (70, 30, 40))
    elif event:
        im = gradient(W, H, (64, 22, 30), (226, 116, 64))
    else:
        im = gradient(W, H, lerp((236, 170, 110), (200, 130, 110), rng.random()), (150, 78, 60))
    d = ImageDraw.Draw(im, "RGBA")
    if space:
        for _ in range(70):
            x, y = rng.uniform(0, W), rng.uniform(0, H * 0.75)
            r = rng.choice([1, 1, 2, 3])
            d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 240, 220, rng.randint(120, 255)))
        # 아래에 행성의 둥근 지평선
        R = W * 1.1
        cy = H * 0.72 + R
        d.ellipse([W / 2 - R, cy - R, W / 2 + R, cy + R], fill=RUST)
        d.ellipse([W / 2 - R, cy - R + 14 * SS, W / 2 + R, cy + R], fill=RUST_D)
        ground = H * 0.78
    else:
        sx = rng.uniform(W * 0.15, W * 0.85)
        d.ellipse([sx - 16 * SS, H * 0.16 - 16 * SS, sx + 16 * SS, H * 0.16 + 16 * SS], fill=(255, 236, 200, 230))
        ridge(d, W, H * 0.56, 22 * SS, RUST_D + (255,), rng, 60 * SS)
        ground = H * 0.66
        d.rectangle([0, ground, W, H], fill=RUST)
        ridge(d, W, H * 0.86, 8 * SS, RUST_L + (90,), rng, 80 * SS)
    cx = W * rng.uniform(0.42, 0.58)

    def block(x, wd, ht, col):
        d.rectangle([x, ground - ht, x + wd, ground], fill=col)
        d.rectangle([x, ground - ht, x + wd * 0.3, ground], fill=lerp(col, (255, 255, 255), 0.18))

    def dome(x, r, col, alpha=255):
        d.pieslice([x - r, ground - r, x + r, ground + r], 180, 360, fill=col + (alpha,))
        d.arc([x - r, ground - r, x + r, ground + r], 180, 360, fill=(255, 255, 255, 110), width=2 * SS)

    for tag in tags[:2]:
        ox = cx + rng.uniform(-60, 60) * SS
        if tag == 0:      # 건물 — 공장 덩어리와 굴뚝
            for k in range(3):
                bw = rng.uniform(26, 44) * SS
                block(ox + (k - 1.5) * 40 * SS, bw, rng.uniform(30, 70) * SS, (88, 84, 96))
            d.rectangle([ox + 30 * SS, ground - 100 * SS, ox + 38 * SS, ground - 40 * SS], fill=(70, 66, 78))
            for k in range(3):
                r = (8 + k * 4) * SS
                d.ellipse([ox + 34 * SS - r + k * 10 * SS, ground - 112 * SS - k * 14 * SS - r, ox + 34 * SS + r + k * 10 * SS, ground - 112 * SS - k * 14 * SS + r],
                          fill=(230, 220, 210, 120))
        elif tag == 1:    # 우주 — 위성(몸통 + 날개판)
            sy = H * rng.uniform(0.25, 0.42)
            d.rectangle([ox - 12 * SS, sy - 9 * SS, ox + 12 * SS, sy + 9 * SS], fill=(200, 204, 214))
            for sgn in (-1, 1):
                x0, x1 = sorted([ox + sgn * 16 * SS, ox + sgn * 52 * SS])
                d.rectangle([x0, sy - 6 * SS, x1, sy + 6 * SS], fill=(70, 110, 190))
                d.line([ox + sgn * 34 * SS, sy - 6 * SS, ox + sgn * 34 * SS, sy + 6 * SS], fill=(200, 220, 255), width=SS)
        elif tag == 2:    # 과학 — 돔과 접시 안테나
            dome(ox, 34 * SS, (210, 214, 224))
            ax = ox + 58 * SS
            d.line([ax, ground, ax, ground - 46 * SS], fill=(60, 60, 72), width=3 * SS)
            d.pieslice([ax - 22 * SS, ground - 70 * SS, ax + 22 * SS, ground - 26 * SS], 200, 340, fill=(226, 226, 236))
        elif tag == 3:    # 식물 — 온실 돔과 싹
            dome(ox, 40 * SS, (150, 220, 170), 170)
            for k in range(7):
                px = ox + (k - 3) * 22 * SS + rng.uniform(-4, 4) * SS
                py = ground + rng.uniform(6, 40) * SS
                d.line([px, py, px, py - 12 * SS], fill=(50, 120, 60), width=2 * SS)
                d.ellipse([px - 7 * SS, py - 22 * SS, px + 7 * SS, py - 8 * SS], fill=(90, 180, 90))
        elif tag == 4:    # 생물 — 배양 구슬
            for k in range(6):
                px = ox + rng.uniform(-70, 70) * SS
                py = ground - rng.uniform(4, 60) * SS
                r = rng.uniform(8, 18) * SS
                d.ellipse([px - r, py - r, px + r, py + r], fill=(70, 170, 150, 220), outline=(220, 255, 240, 200), width=SS)
                d.ellipse([px - r * 0.3, py - r * 0.3, px + r * 0.1, py + r * 0.1], fill=(230, 255, 245, 200))
        elif tag == 5:    # 전력 — 바람개비 셋(또는 태양판)
            if "solar" in extra:
                for k in range(5):
                    px = ox + (k - 2) * 34 * SS
                    d.polygon([(px - 14 * SS, ground), (px + 14 * SS, ground), (px + 20 * SS, ground - 18 * SS), (px - 8 * SS, ground - 18 * SS)], fill=(60, 90, 170))
            else:
                for k in range(3):
                    px = ox + (k - 1) * 46 * SS
                    top = ground - (70 + k * 8) * SS
                    d.line([px, ground, px, top], fill=(232, 232, 236), width=3 * SS)
                    for a in range(3):
                        ang = a * 2.094 + idx
                        d.line([px, top, px + math.cos(ang) * 26 * SS, top + math.sin(ang) * 26 * SS], fill=(240, 240, 244), width=3 * SS)
        elif tag == 6:    # 도시 — 큰 돔 안의 건물들
            for k in range(6):
                block(ox + (k - 3) * 20 * SS, 16 * SS, rng.uniform(24, 66) * SS, (120, 126, 146))
            dome(ox, 76 * SS, (190, 220, 240), 60)
    if "trees" in extra:
        for k in range(8):
            px = rng.uniform(0.08, 0.92) * W
            py = ground + rng.uniform(10, 60) * SS
            d.rectangle([px - 2 * SS, py - 10 * SS, px + 2 * SS, py], fill=(80, 50, 30))
            d.ellipse([px - 11 * SS, py - 30 * SS, px + 11 * SS, py - 8 * SS], fill=(60, 140, 70))
    if "ocean" in extra:
        d.rectangle([0, H * 0.84, W, H], fill=(40, 100, 190))
        d.line([0, H * 0.84, W, H * 0.84], fill=(170, 210, 250), width=2 * SS)
    if "ice" in extra:
        ridge(d, W, H * 0.8, 6 * SS, (232, 240, 250, 255), rng, 50 * SS)
    if "cloud" in extra:
        for k in range(4):
            px, py = rng.uniform(0.1, 0.9) * W, rng.uniform(0.12, 0.35) * H
            for j in range(3):
                d.ellipse([px + j * 18 * SS - 20 * SS, py - 12 * SS, px + j * 18 * SS + 20 * SS, py + 12 * SS], fill=(250, 244, 236, 170))
    if "heat" in extra:
        for k in range(5):
            px = cx + (k - 2) * 30 * SS
            d.polygon([(px - 9 * SS, ground), (px + 9 * SS, ground), (px, ground - rng.uniform(26, 50) * SS)], fill=(255, 170, 60, 210))
    if "meteor" in extra:
        mx, my = W * 0.68, H * 0.3
        d.polygon([(mx, my), (mx + 150 * SS, my - 96 * SS), (mx + 160 * SS, my - 80 * SS)], fill=(255, 220, 150, 170))
        d.ellipse([mx - 12 * SS, my - 12 * SS, mx + 12 * SS, my + 12 * SS], fill=(255, 244, 220))
    if "burst" in extra:
        bx, by = cx, ground - 20 * SS
        for a in range(12):
            ang = a * math.pi / 6
            d.polygon([(bx, by), (bx + math.cos(ang - 0.08) * 90 * SS, by + math.sin(ang - 0.08) * 60 * SS),
                       (bx + math.cos(ang + 0.08) * 90 * SS, by + math.sin(ang + 0.08) * 60 * SS)], fill=(255, 210, 120, 150))
        d.ellipse([bx - 22 * SS, by - 22 * SS, bx + 22 * SS, by + 22 * SS], fill=(255, 240, 200))
    if kind == 1:        # 운영 — 아래에 띠 하나(되풀이하는 시설)
        d.rectangle([0, H - 10 * SS, W, H], fill=(60, 110, 190, 200))
    return im.resize((w, h), Image.LANCZOS)


def rs_bg(board, w=480, h=270):
    rng = random.Random(77 if board else 78)
    W, H = w * SS, h * SS
    if board:
        im = gradient(W, H, (44, 20, 20), (26, 14, 16))
        d = ImageDraw.Draw(im, "RGBA")
        for k in range(14):   # 등고선
            cx, cy = rng.uniform(0, W), rng.uniform(0, H)
            for j in range(4):
                r = (40 + j * 26) * SS * rng.uniform(0.8, 1.2)
                d.ellipse([cx - r * 1.5, cy - r, cx + r * 1.5, cy + r], outline=(200, 110, 80, 22), width=SS)
        return im.resize((w, h), Image.LANCZOS)
    im = gradient(W, H, (40, 22, 44), (230, 120, 70))
    d = ImageDraw.Draw(im, "RGBA")
    d.rectangle([0, H * 0.52, W, H * 0.54], fill=(110, 200, 190, 70))   # 새 대기의 푸른 띠
    for (mx, my, r) in [(0.78, 0.2, 9), (0.86, 0.3, 5)]:
        d.ellipse([W * mx - r * SS, H * my - r * SS, W * mx + r * SS, H * my + r * SS], fill=(240, 226, 210))
    ridge(d, W, H * 0.6, 14 * SS, (120, 54, 40, 255), rng, 70 * SS)
    d.rectangle([0, H * 0.68, W, H], fill=(96, 42, 34))
    ridge(d, W, H * 0.8, 10 * SS, (70, 30, 28, 255), rng, 90 * SS)
    cx, g = W * 0.5, H * 0.68
    d.pieslice([cx - 30 * SS, g - 30 * SS, cx + 30 * SS, g + 30 * SS], 180, 360, fill=(255, 220, 150, 200))
    return im.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))


# ==================== 잿빛 요새의 용병단 — 초상 15 · 배경 2 ====================

def ak_portrait(side, k, base, s=256):
    S = s * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dark = lerp(base, (10, 8, 12), 0.72)
    bg = Image.new("RGB", (S, S), dark)
    bd = ImageDraw.Draw(bg)
    for r in range(S // 2, 0, -4):
        bd.ellipse([S / 2 - r, S * 0.62 - r, S / 2 + r, S * 0.62 + r], fill=lerp(lerp(base, (20, 14, 16), 0.45), dark, r / (S / 2)))
    d = ImageDraw.Draw(bg, "RGBA")
    c = S / 2
    body = lerp(base, (0, 0, 0), 0.55)
    lite = lerp(base, (255, 240, 220), 0.55)
    ember = (255, 150, 70)

    def P(pts, col):
        d.polygon([(c + x * S, c + y * S) for x, y in pts], fill=col)

    def E(x, y, rx, ry, col):
        d.ellipse([c + (x - rx) * S, c + (y - ry) * S, c + (x + rx) * S, c + (y + ry) * S], fill=col)

    def shoulders(col=body):
        P([(-0.36, 0.5), (-0.26, 0.2), (0.26, 0.2), (0.36, 0.5)], col)

    if side == "h":
        shoulders()
        if k == 0:      # 방패 파수꾼 — 투구와 둥근 방패
            E(0, -0.04, 0.17, 0.2, lite)
            P([(-0.17, -0.06), (0.17, -0.06), (0.17, 0.02), (-0.17, 0.02)], body)
            P([(-0.03, -0.24), (0.03, -0.24), (0.03, 0.1), (-0.03, 0.1)], body)
            E(0.26, 0.3, 0.2, 0.2, (150, 160, 180)); E(0.26, 0.3, 0.13, 0.13, base); E(0.26, 0.3, 0.04, 0.04, lite)
        elif k == 1:    # 재 마녀 — 뾰족한 두건과 손의 불씨
            P([(-0.24, 0.12), (0, -0.42), (0.24, 0.12)], body)
            E(0, 0.02, 0.12, 0.14, lite)
            E(-0.05, 0.0, 0.025, 0.02, ember); E(0.05, 0.0, 0.025, 0.02, ember)
            P([(0.2, 0.36), (0.3, 0.12), (0.34, 0.26), (0.4, 0.18), (0.4, 0.38)], ember)
        elif k == 2:    # 그림자 척후 — 두건과 엇갈린 단검
            E(0, -0.06, 0.2, 0.22, body)
            E(0, 0.0, 0.13, 0.1, lite)
            P([(-0.14, 0.02), (0.14, 0.02), (0.14, 0.12), (-0.14, 0.12)], body)
            for sgn in (-1, 1):
                P([(sgn * 0.3, 0.44), (sgn * 0.34, 0.4), (sgn * 0.06, 0.16), (sgn * 0.03, 0.2)], (210, 214, 226))
        else:           # 성가 치유사 — 후드와 등불
            E(0, -0.06, 0.2, 0.22, (236, 230, 214))
            E(0, -0.02, 0.12, 0.13, lerp(lite, (255, 255, 255), 0.3))
            P([(0.24, 0.1), (0.36, 0.1), (0.38, 0.32), (0.22, 0.32)], (90, 70, 40))
            E(0.3, 0.21, 0.05, 0.08, (255, 226, 130))
    else:
        if k == 0:      # 재바람 추종자 — 가면
            shoulders(); E(0, -0.04, 0.17, 0.21, lite)
            for sgn in (-1, 1):
                P([(sgn * 0.11, -0.08), (sgn * 0.03, -0.05), (sgn * 0.11, -0.01)], body)
            P([(-0.06, 0.08), (0.06, 0.08), (0, 0.12)], body)
        elif k == 1:    # 굴뚝 궁수 — 활
            shoulders(); E(-0.06, -0.04, 0.14, 0.16, lite)
            d.arc([c + 0.08 * S, c - 0.34 * S, c + 0.5 * S, c + 0.42 * S], 100, 260, fill=(120, 80, 40), width=int(0.03 * S))
            d.line([c + 0.2 * S, c - 0.3 * S, c + 0.2 * S, c + 0.38 * S], fill=(230, 230, 220), width=max(2, int(0.008 * S)))
        elif k == 2:    # 용암 굴착충 — 이빨 달린 둥근 입
            E(0, 0.06, 0.34, 0.34, body); E(0, 0.06, 0.22, 0.22, (40, 10, 10))
            for a in range(10):
                ang = a * math.pi / 5
                P([(math.cos(ang - 0.18) * 0.22, 0.06 + math.sin(ang - 0.18) * 0.22), (math.cos(ang + 0.18) * 0.22, 0.06 + math.sin(ang + 0.18) * 0.22),
                   (math.cos(ang) * 0.1, 0.06 + math.sin(ang) * 0.1)], ember)
        elif k == 3:    # 잿불 정령 — 눈 달린 불꽃
            P([(-0.22, 0.34), (-0.26, 0.0), (-0.1, -0.16), (-0.04, -0.4), (0.12, -0.14), (0.24, -0.02), (0.22, 0.34)], ember)
            P([(-0.12, 0.34), (-0.12, 0.08), (0, -0.14), (0.12, 0.08), (0.12, 0.34)], (255, 226, 140))
            E(-0.06, 0.12, 0.03, 0.04, (255, 255, 255)); E(0.06, 0.12, 0.03, 0.04, (255, 255, 255))
        elif k == 4:    # 무덤 파수병 — 해골과 큰 방패
            shoulders(); E(0, -0.06, 0.16, 0.18, (226, 222, 210))
            E(-0.06, -0.06, 0.04, 0.05, (90, 170, 250)); E(0.06, -0.06, 0.04, 0.05, (90, 170, 250))
            P([(-0.05, 0.08), (0.05, 0.08), (0.05, 0.13), (-0.05, 0.13)], body)
            P([(0.12, 0.14), (0.42, 0.14), (0.42, 0.44), (0.27, 0.5), (0.12, 0.44)], (130, 136, 150))
        elif k == 5:    # 독안개 주술사 — 외눈과 지팡이
            shoulders(); E(0, -0.04, 0.18, 0.2, body); E(0, -0.04, 0.09, 0.07, (190, 240, 140)); E(0, -0.04, 0.03, 0.05, (20, 40, 20))
            d.line([c - 0.3 * S, c + 0.46 * S, c - 0.26 * S, c - 0.34 * S], fill=(110, 80, 50), width=int(0.025 * S))
            E(-0.26, -0.36, 0.06, 0.06, (150, 230, 110))
        elif k == 6:    # 표범 사냥개 — 뾰족한 귀
            P([(-0.26, 0.3), (-0.3, -0.26), (-0.12, -0.08), (0.12, -0.08), (0.3, -0.26), (0.26, 0.3), (0, 0.44)], lite)
            E(-0.11, 0.06, 0.035, 0.035, ember); E(0.11, 0.06, 0.035, 0.035, ember)
            P([(-0.05, 0.28), (0.05, 0.28), (0, 0.35)], body)
            for (x, y) in [(-0.16, -0.02), (0.18, 0.16), (-0.04, 0.16), (0.1, -0.02)]:
                E(x, y, 0.025, 0.025, body)
        elif k == 7:    # 불배 큰수레 — 바퀴 달린 수레와 불
            P([(-0.34, 0.26), (-0.3, -0.02), (0.3, -0.02), (0.34, 0.26)], (110, 74, 44))
            E(-0.2, 0.3, 0.1, 0.1, body); E(0.2, 0.3, 0.1, 0.1, body); E(-0.2, 0.3, 0.03, 0.03, lite); E(0.2, 0.3, 0.03, 0.03, lite)
            P([(-0.16, -0.02), (-0.2, -0.22), (-0.06, -0.12), (0, -0.36), (0.08, -0.12), (0.2, -0.2), (0.16, -0.02)], ember)
        elif k == 8:    # 봉인석 — 금 간 마름모 수정
            P([(0, -0.38), (0.22, 0.02), (0, 0.42), (-0.22, 0.02)], lite)
            P([(0, -0.38), (0.22, 0.02), (0, 0.42)], lerp(lite, (0, 0, 0), 0.25))
            d.line([c - 0.04 * S, c - 0.2 * S, c + 0.05 * S, c, c - 0.03 * S, c + 0.2 * S], fill=(255, 255, 255, 220), width=max(2, int(0.012 * S)))
        elif k == 9:    # 재의 군주 — 불씨 왕관
            shoulders(lerp(body, (0, 0, 0), 0.3)); E(0, 0.0, 0.2, 0.22, body)
            P([(-0.2, -0.12), (-0.2, -0.36), (-0.1, -0.2), (0, -0.42), (0.1, -0.2), (0.2, -0.36), (0.2, -0.12)], ember)
            E(-0.08, 0.0, 0.04, 0.025, (255, 220, 120)); E(0.08, 0.0, 0.04, 0.025, (255, 220, 120))
        else:           # 심연의 장인 — 가면과 여러 팔
            for a in range(6):
                ang = math.pi + a * math.pi / 5
                d.line([c, c + 0.2 * S, c + math.cos(ang) * 0.42 * S, c + 0.2 * S + math.sin(ang) * 0.42 * S], fill=(120, 124, 140), width=int(0.03 * S))
            shoulders(); E(0, -0.02, 0.15, 0.2, (226, 222, 232))
            P([(-0.1, -0.04), (-0.03, -0.02), (-0.1, 0.02)], (150, 70, 220)); P([(0.1, -0.04), (0.03, -0.02), (0.1, 0.02)], (150, 70, 220))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([2, 2, S - 3, S - 3], fill=255)
    im.paste(bg, (0, 0), mask)
    return im.resize((s, s), Image.LANCZOS)


def ak_bg(board, w=480, h=270):
    rng = random.Random(41 if board else 42)
    W, H = w * SS, h * SS
    if board:
        im = gradient(W, H, (34, 32, 36), (20, 18, 22))
        d = ImageDraw.Draw(im, "RGBA")
        for k in range(40):   # 돌바닥 이음매와 불씨 금
            x, y = rng.uniform(0, W), rng.uniform(0, H)
            ln = rng.uniform(30, 120) * SS
            ang = rng.choice([0, math.pi / 2]) + rng.uniform(-0.1, 0.1)
            col = (230, 120, 60, 26) if k % 7 == 0 else (0, 0, 0, 60)
            d.line([x, y, x + math.cos(ang) * ln, y + math.sin(ang) * ln], fill=col, width=SS)
        return im.resize((w, h), Image.LANCZOS)
    im = gradient(W, H, (60, 56, 62), (150, 96, 70))
    d = ImageDraw.Draw(im, "RGBA")
    vx = W * 0.82
    d.polygon([(vx - 120 * SS, H * 0.62), (vx - 20 * SS, H * 0.34), (vx + 20 * SS, H * 0.34), (vx + 130 * SS, H * 0.62)], fill=(64, 54, 58))
    d.ellipse([vx - 30 * SS, H * 0.26, vx + 30 * SS, H * 0.4], fill=(255, 150, 70, 150))
    ridge(d, W, H * 0.62, 10 * SS, (50, 46, 50, 255), rng, 80 * SS)
    fx = W * 0.36   # 언덕 위의 무너진 요새
    d.polygon([(fx - 160 * SS, H * 0.7), (fx, H * 0.5), (fx + 170 * SS, H * 0.7)], fill=(40, 36, 40))
    for k in range(5):
        bx = fx + (k - 2) * 26 * SS
        ht = [34, 58, 44, 70, 30][k] * SS
        d.rectangle([bx - 11 * SS, H * 0.54 - ht, bx + 11 * SS, H * 0.58], fill=(30, 28, 32))
    d.rectangle([0, H * 0.7, W, H], fill=(34, 30, 34))
    for k in range(120):  # 떨어지는 재
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        d.ellipse([x, y, x + 2 * SS, y + 2 * SS], fill=(230, 224, 216, rng.randint(40, 130)))
    d.ellipse([W * 0.2 - 8 * SS, H * 0.84 - 8 * SS, W * 0.2 + 8 * SS, H * 0.84 + 8 * SS], fill=(255, 170, 80, 230))   # 모닥불
    return im.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))


AK_HERO_COL = [(90, 130, 200), (220, 100, 60), (110, 80, 150), (230, 200, 110)]
AK_MON_COL = [(150, 120, 110), (120, 140, 110), (180, 80, 50), (250, 150, 60), (140, 140, 160), (110, 160, 90), (200, 160, 80), (160, 90, 70),
              (170, 150, 220), (200, 60, 40), (120, 60, 160)]


def main() -> int:
    jobs = {}
    for i, (kind, tags, extra) in enumerate(RS_CARDS):
        jobs["redstar/rs_c_%d" % i] = lambda i=i, kind=kind, tags=tags, extra=extra: rs_card(i, kind, tags, extra)
    jobs["redstar/rs_bg_title"] = lambda: rs_bg(False)
    jobs["redstar/rs_bg_board"] = lambda: rs_bg(True)
    for k in range(4):
        jobs["ashkeep/ak_h_%d" % k] = lambda k=k: ak_portrait("h", k, AK_HERO_COL[k])
    for k in range(11):
        jobs["ashkeep/ak_m_%d" % k] = lambda k=k: ak_portrait("m", k, AK_MON_COL[k])
    jobs["ashkeep/ak_bg_title"] = lambda: ak_bg(False)
    jobs["ashkeep/ak_bg_board"] = lambda: ak_bg(True)
    if os.path.exists(LIST):
        with open(LIST, encoding="utf-8") as f:
            allowed = {ln.strip() for ln in f if ln.strip() and not ln.startswith("#")}
    else:
        allowed = set(jobs)
        with open(LIST, "w", encoding="utf-8", newline="\n") as f:
            f.write("# 임시 그림 목록 — tools/temp_art.py 가 다시 쓰는 이름. AI 그림으로 바꾼 이름은 여기서 지운다(안 지우면 스크립트가 덮어쓴다).\n")
            f.write("\n".join(sorted(jobs)) + "\n")
    n = 0
    for name, make in jobs.items():
        if name not in allowed:
            continue
        path = os.path.join(ROOT, "art", name + ".png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        make().save(path, optimize=True)
        n += 1
    print("임시 그림 %d장" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
