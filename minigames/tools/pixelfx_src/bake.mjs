// 비술난무 시트 굽기 — pixelfx(MIT, https://github.com/patch-gg/pixelfx) 로 주인공 동작을 칸 크기 고정 시트로 굽는다.
//   node tools/pixelfx_src/bake.mjs [출력 폴더] [--strip]
// pixelfx 저장소 위치는 환경 변수 PIXELFX (기본 C:/dev/pixelfx). 게임은 실행 중에 이걸 안 부른다 — 결과 PNG · JSON 만 쓴다.
// 시트 모양: 한 줄 = 동작 하나, 칸 CW×CH, 발(피벗)은 칸 안 (PX, PY). JSON 에 동작마다 줄 · 장수 · fps · loop 를 적는다.

import { pathToFileURL } from "node:url";
import { join } from "node:path";
import { writeFileSync, mkdirSync } from "node:fs";
import { ANIMS } from "./hero.mjs";
import { FOE } from "./foe.mjs";
import { setLook, skeleton } from "./core/rig.js";

const PF = (process.env.PIXELFX ?? "C:/dev/pixelfx").replace(/\\/g, "/");
// 주인공은 고친 복사본(./core — 여성 격투가 색 · 포니테일)으로 굽는다. 이펙트는 pixelfx 원본 render.mjs 로.
const core = await import(new URL("./core/index.js", import.meta.url).href);
const lib = await import(pathToFileURL(join(PF, "tools/lib/fxlib.mjs")).href);
const { createAct, createFrame, clearFrame, composite } = core;

const CW = 88, CH = 66, PX = 38, PY = 66, FPS = 12;   // PY = CH: 발 줄이 칸 밖이라 pixelfx 가 바닥 그림자를 안 그린다(공중 동작에 그림자가 붙어 다니지 않게)
const out = process.argv[2] && !process.argv[2].startsWith("--") ? process.argv[2] : "art/mystic";
const strip = process.argv.includes("--strip");
mkdirSync(out, { recursive: true });


// 컷아웃용 관절 자리 — pixelfx skeleton() 을 발 기준으로 옮기고 0.1 단위로 줄인다.
function bonesOf(pose) {
  const sk = skeleton(pose), ox = pose.x ?? 0, oy = pose.y ?? 0, out = {};
  for (const [k, v] of Object.entries(sk.joints)) out[k] = [Math.round((v[0] + ox) * 10) / 10, Math.round((v[1] + oy) * 10) / 10, Math.round(v[2] * 10) / 10];
  return out;
}

function frames(name, a) {
  const poses = a.poses, t0 = poses[0][0], t1 = a.loop ? a.dur : poses[poses.length - 1][0];
  const mod = {
    meta: { name, size: [CW, CH], origin: [PX, PY], duration: a.loop ? a.dur : Math.max(0.05, t1), loop: !!a.loop, fps: FPS, actor: 2, options: { seed: 1 } },
    act: { poses },
    draw() {},
  };
  const act = createAct(mod, { x: PX, y: PY });
  const f = createFrame(CW, CH), list = [];
  list.bones = [];   // 프레임마다 관절 자리(컷아웃용) — 발 기준 px, y 아래가 +, z 관객 쪽이 +
  // createAct 는 첫 키에서 시작한다 — 12fps 로 한 칸씩
  const n = Math.max(1, Math.round((t1 - t0) * FPS) + (a.loop ? 0 : 1));
  for (let i = 0; i < n; i++) {
    clearFrame(f);
    act.draw(f, { body: true, target: false });
    list.push(composite(f, new Uint8ClampedArray(CW * CH * 4), null));
    list.bones.push(bonesOf(act.pose));
    act.update(1 / FPS);
  }
  return list;
}

// 시트 하나 — 한 줄 = 동작 하나. look: "fighter"(주인공) · "knight"(병사 · 보스 — pixelfx 원래 기사)
function bakeSheet(file, anims, look) {
  setLook(look);
  const names = Object.keys(anims), rows = names.map((k) => frames(k, anims[k]));
  const cols = Math.max(...rows.map((r) => r.length));
  const img = lib.canvas(cols * CW, rows.length * CH, [0, 0, 0, 0]);
  const meta = { cell: [CW, CH], pivot: [PX, PY], anims: {} };
  rows.forEach((r, j) => {
    r.forEach((px, i) => img.paste(px, CW, CH, i * CW, j * CH));
    meta.anims[names[j]] = { row: j, n: r.length, fps: FPS, loop: !!anims[names[j]].loop };
  });
  writeFileSync(join(out, `${file}.png`), img.png());
  writeFileSync(join(out, `${file}.json`), JSON.stringify(meta, null, 1));
  // 관절 자리 — 동작마다 프레임 목록. 게임의 컷아웃(AI 부위 그림)이 이것을 따라 움직인다
  writeFileSync(join(out, `${file}_bones.json`), JSON.stringify(Object.fromEntries(names.map((k, j) => [k, rows[j].bones]))));
  console.log(`${file}  ${names.length} anims, ${cols} cols  ->  ${out}/${file}.png`);
  if (strip) {
    // 확인용: 4배로 키운 시트(어두운 바탕)
    const k = 4, big = lib.canvas(cols * CW * k, rows.length * CH * k, [24, 22, 34, 255]);
    rows.forEach((r, j) => r.forEach((px, i) => big.paste(lib.upscale(px, CW, CH, k), CW * k, CH * k, i * CW * k, j * CH * k)));
    writeFileSync(join(out, `${file}_strip.png`), big.png());
  }
}
bakeSheet("ms_hero", ANIMS, "fighter");
bakeSheet("ms_foe", FOE, "knight");

// ---------- 이펙트 · 적: pixelfx 의 render.mjs --sheet 로 굽고 이름만 바꿔 옮긴다 ----------
// [pixelfx id, 게임 이름, 추가 인자]. 캐릭터 없이(--no-actor) 이펙트만 굽는다 — 자리는 게임이 맞춘다.
const FX = [
  ["impacts/hit-spark", "fx_hit"],
  ["impacts/crit-hit", "fx_crit"],
  ["melee/sword-slash", "fx_slash1"],
  ["melee/double-slash", "fx_slash2"],
  ["melee/uppercut", "fx_launch"],
  ["melee/thrust", "fx_dash"],
  ["melee/spin-slash", "fx_rise"],
  ["arcane/arcane-orb", "fx_orb"],
  ["impacts/ground-slam", "fx_stomp"],
  ["lightning/lightning-strike", "fx_dive"],
  ["spawn/poof", "fx_poof"],
  ["critters/slime", "en_slime"],
  ["critters/bat", "en_bat"],
  ["critters/ghost", "en_ghost"],
  ["critters/flying-skull", "en_skull"],
];
if (!process.argv.includes("--hero-only")) {
  const { execFileSync } = await import("node:child_process");
  const { copyFileSync } = await import("node:fs");
  for (const [id, name, ...extra] of FX) {
    execFileSync(process.execPath, [join(PF, "tools/render.mjs"), id, "--sheet", "--no-actor", "--fps", "15", ...extra], { cwd: PF, stdio: "ignore" });
    const base = id.split("/")[1], dir = join(PF, "records", ...id.split("/"));
    copyFileSync(join(dir, `${base}.png`), join(out, `${name}.png`));
    copyFileSync(join(dir, `${base}.json`), join(out, `${name}.json`));
    console.log(`${name}  <-  ${id}`);
  }
}
