#!/usr/bin/env python3
"""게임별 글꼴을 받아 필요한 글자만 남긴 파일(font/mg_*.ttf)로 만든다.

    pip install fonttools
    python tools/font_subset.py            # minigames/ 에서. 원본은 tools/.font_src/ 에 받아 둔다(저장소에 안 올림)
    godot --headless --path . --import     # 새 파일을 Godot 이 들여오게

왜 줄이나: 웹 빌드라 글꼴 파일을 싣는다(브라우저에 한글 글꼴이 없다). 원본은 1~8MB 씩이라 그대로는 못 싣는다.
  본문 글꼴 = KS X 1001 한글 2350자 + ASCII + 기호 + 소스에 나오는 모든 글자
  타이틀 글꼴 = 게임 이름 · 소개 줄 · 큰 제목 낱말(아래 TITLE_TEXT) + ASCII (빠진 글자는 본문 글꼴 → Jua 순서로 메운다 — UiKit.font)
**타이틀 글꼴로 새 글자를 쓰려면 TITLE_TEXT 에 넣고 이 스크립트를 다시 돌린다**(안 넣으면 그 글자만 본문 글꼴로 나와 얼룩진다).

글꼴은 전부 SIL OFL(font/LICENSES.md). OFL 은 고친 글꼴에 예약된 이름을 못 쓰게 하므로 이름표를 "MG ..." 로 바꾼다(저작권 · 라이선스 줄은 그대로 둔다).
"""
import glob
import os
import sys
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(HERE, ".font_src")
OUT = os.path.join(ROOT, "font")
BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl/"

# 타이틀 글꼴에 남길 글자 — 게임 이름과 큰 제목(결과 · 단계 이름)에 쓰는 낱말
COMMON = "승리패배무승부결과규칙시작끝완성성공실패기록순위도감다시하기처음으로라운드세대시대단계차례나상대"
TITLE_TEXT = {
    "sky": "스카이 어설트 출격 격추 임무 완수 기체 보스 연습 게임 오버 클리어",
    "runner": "월드 러너 게임 파산 우승 독점 무인도 황금열쇠 우주여행 출발",
    "gangho": "강호일생 태어나기 천하력 묘비 인생 일류 절정 화경 현경 삼류 이류 무림맹주 세 살",
    "arcana": "아르카나 컬렉션 영웅 성물 전당 봉인",
    "empire": "제국 연대기 문명 군사 과학 불가사의 일이삼",
    "redstar": "붉은 별 개척단 온도 대기 바다 개척 등급 연구 생산",
    "ashkeep": "잿빛 요새의 용병단 야영지 시나리오 쓰러짐 휴식 출발",
}

# 출력 이름: (원본 경로, 종류, 타이틀이면 TITLE_TEXT 의 열쇠, 가변 글꼴이면 굵기)
FONTS = {
    "mg_sky_title": ("blackhansans/BlackHanSans-Regular.ttf", "title", ["sky"], None),
    "mg_sky_body": ("dohyeon/DoHyeon-Regular.ttf", "body", [], None),
    "mg_runner_title": ("sunflower/Sunflower-Bold.ttf", "title", ["runner"], None),   # Gugi 는 "너" 가 "니" 로 읽혀서 바꿈
    "mg_gangho_title": ("nanumbrushscript/NanumBrushScript-Regular.ttf", "title", ["gangho"], None),
    "mg_serif_body": ("songmyung/SongMyung-Regular.ttf", "body", [], None),          # 강호 · 제국 본문
    "mg_arcana_title": ("hahmlet/Hahmlet%5Bwght%5D.ttf", "title", ["arcana"], 800),
    "mg_batang_body": ("gowunbatang/GowunBatang-Bold.ttf", "body", [], None),        # 아르카나 · 잿빛 요새 본문
    "mg_empire_title": ("nanummyeongjo/NanumMyeongjo-ExtraBold.ttf", "title", ["empire"], None),
    "mg_redstar_title": ("ibmplexsanskr/IBMPlexSansKR-Bold.ttf", "title", ["redstar"], None),
    "mg_redstar_body": ("ibmplexsanskr/IBMPlexSansKR-Medium.ttf", "body", [], None),
    "mg_ashkeep_title": ("yeonsung/YeonSung-Regular.ttf", "title", ["ashkeep"], None),
}

ASCII = "".join(chr(c) for c in range(0x20, 0x7F))
SYMBOLS = "·—–×→←↑↓…「」★☆−÷₩°±≥≤※▲▼◆●○■□♥♪✓"


def ksx1001() -> str:
    out = []
    for a in range(0xB0, 0xC9):
        for b in range(0xA1, 0xFF):
            try:
                out.append(bytes([a, b]).decode("euc-kr"))
            except UnicodeDecodeError:
                pass
    return "".join(out)


def chars_in(dirs) -> str:
    seen = set()
    for d in dirs:
        for path in glob.glob(os.path.join(ROOT, "src", d, "**", "*.gd"), recursive=True):
            with open(path, encoding="utf-8") as f:
                seen.update(ch for ch in f.read() if ord(ch) > 0x7F)
    return "".join(sorted(seen))


def fetch(rel: str) -> str:
    os.makedirs(SRC, exist_ok=True)
    path = os.path.join(SRC, os.path.basename(rel).replace("%5Bwght%5D", "-VF"))
    if not os.path.exists(path):
        print("받는 중", rel)
        urllib.request.urlretrieve(BASE + rel, path)
    return path


def main() -> int:
    all_src = chars_in(["."])
    body_text = ASCII + SYMBOLS + ksx1001() + all_src
    for name, (rel, kind, dirs, wght) in FONTS.items():
        font = TTFont(fetch(rel))
        if wght is not None:
            font = instancer.instantiateVariableFont(font, {"wght": wght})
        text = body_text if kind == "body" else ASCII + COMMON + "".join(TITLE_TEXT[d] for d in dirs)
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
        opts.notdef_outline = True
        opts.glyph_names = False
        sub = subset.Subsetter(opts)
        sub.populate(text=text)
        sub.subset(font)
        label = "MG " + name[3:].replace("_", " ").title()
        for rec in font["name"].names:
            if rec.nameID in (1, 4, 16):
                rec.string = label
            elif rec.nameID == 6:
                rec.string = label.replace(" ", "")
            elif rec.nameID == 3:
                rec.string = label + " (subset)"
        out = os.path.join(OUT, name + ".ttf")
        font.save(out)
        print("%-18s %-5s %5d 글자  %4d KB" % (name, kind, len(font.getBestCmap()), os.path.getsize(out) // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
