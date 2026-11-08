// 비술난무 병사 · 보스 동작표 — pixelfx 원래 회색 기사(칼을 든 마네킹). 게임이 색을 입힌다(병사 붉게, 보스는 스테이지마다).
// 주인공 시트를 색만 바꿔 쓰면 적이 여성 격투가 복제로 보여서 따로 굽는다.
// 이름은 게임이 그대로 찾는다: walk · atk1(베기) · stomp(보스 찍기) · wave(보스 구 쏘기) · hurt · idle.

const READY = { crouch: 3, fx: 11, fy: -21, bx: 9, by: -21, ffx: 7, fbx: -7 };
const G = { ...READY, weapon: "sword", fx: 12, fy: -21, sa: -0.85 };

export const FOE = {
  idle: { loop: true, dur: 1.0, poses: [[0, G], [0.5, { ...G, crouch: 4, fy: -20, by: -20 }], [1.0, G]] },
  walk: {
    loop: true, dur: 0.6, poses: [
      [0, { ...G, ffx: 8, fbx: -6, fby: -6 }],
      [0.15, { ...G, crouch: 2, ffx: 2, fbx: 1 }],
      [0.3, { ...G, ffx: -6, fbx: 8, ffy: -6 }],
      [0.45, { ...G, crouch: 2, ffx: 1, fbx: 2 }],
      [0.6, { ...G, ffx: 8, fbx: -6, fby: -6 }],
    ],
  },
  // 첫 칸이 예비 동작(칼을 뒤로) — 게임은 cast 동안 0초째 칸을 붙들고 있는다
  atk1: {
    loop: false, poses: [
      [0, { ...G, fx: -2, fy: -34, sa: -2.4, lean: -3 }],
      [0.08, { ...G, crouch: 4, lean: 4, fx: 18, fy: -22, sa: 0.4, ffx: 11, fbx: -9, ghost: 1 }, "snap"],
      [0.25, { ...G, crouch: 4, lean: 3, fx: 17, fy: -20, sa: 0.5, ffx: 11, fbx: -9 }],
    ],
  },
  stomp: {
    loop: false, poses: [
      [0, { ...G, crouch: 0, lean: -5, fx: 2, fy: -44, sa: -1.57, bx: 4, by: -42, two: true, toeF: true, toeB: true }],
      [0.12, { ...G, crouch: 9, lean: 9, fx: 14, fy: -9, sa: 1.45, bx: 12, by: -11, two: true, ffx: 10, fbx: -10, ghost: 1 }, "snap"],
      [0.42, { ...G, crouch: 8, lean: 8, fx: 14, fy: -9, sa: 1.45, bx: 12, by: -11, two: true, ffx: 10, fbx: -10 }],
    ],
  },
  wave: {
    loop: false, poses: [
      [0, { ...G, crouch: 5, lean: -4, fx: -6, fy: -20, bx: -4, by: -22, sa: 2.4, armsFront: true }],
      [0.12, { ...G, crouch: 4, lean: 5, fx: 4, fy: -14, sa: 1.4, bx: 19, by: -25, ffx: 12, fbx: -10, ghost: 1 }, "snap"],
      [0.4, { ...G, crouch: 4, lean: 4, fx: 4, fy: -15, sa: 1.4, bx: 18, by: -25, ffx: 12, fbx: -10 }],
    ],
  },
  hurt: { loop: false, poses: [[0, { ...G, lean: -7, crouch: 3, fx: 4, fy: -24, sa: -1.6, hx: -2 }], [0.25, { ...G, lean: -7, crouch: 3, fx: 4, fy: -24, sa: -1.6 }]] },
};
