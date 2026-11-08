// 비술난무 주인공(여성 격투가) 동작표 — pixelfx 뼈대 캐릭터에 자세만 준다. 이펙트는 따로 굽는다.
// 자세 칸의 뜻은 core/poses.js 머리 주석: 발에서 잰 px, y 는 위가 음수, fx/fy 앞손, bx/by 뒷손,
// ffx/ffy · fbx/fby 앞발 · 뒷발, crouch 무릎, lean 허리, yaw 몸 전체 돌기(0 = 오른쪽 옆모습, 클수록 관객 쪽).
// **서 있을 때는 앞면 위주**(yaw 0.85, 사용자 요청 11-08 "옆면만 보인다") — 치고 찰 때만 옆으로 돌아
// 주먹 · 발이 앞으로 뻗는 게 읽히게 한다. 맨손이라 무기는 없다.
// 시간은 초. loop 인 것은 0 ~ dur 이 이어지고, 아닌 것은 첫 키 ~ 마지막 키를 12fps 로 자른다.

const FRONT = 0.85;
// 격투 자세 — 두 주먹을 얼굴 앞에
const G = { crouch: 3, yaw: FRONT, fx: 7, fy: -27, bx: 10, by: -29, armsFront: true, ffx: 6, fbx: -6 };
const AIRLEG = { ffx: 5, ffy: -9, fbx: -4, fby: -13 };

export const ANIMS = {
  idle: { loop: true, dur: 1.0, poses: [[0, G], [0.5, { ...G, crouch: 4, fy: -26, by: -28 }], [1.0, G]] },
  walk: {
    loop: true, dur: 0.5, poses: [
      [0, { ...G, yaw: 0.6, ffx: 8, fbx: -6, fby: -6 }],
      [0.125, { ...G, yaw: 0.6, crouch: 2, ffx: 2, fbx: 1 }],
      [0.25, { ...G, yaw: 0.6, ffx: -6, fbx: 8, ffy: -6 }],
      [0.375, { ...G, yaw: 0.6, crouch: 2, ffx: 1, fbx: 2 }],
      [0.5, { ...G, yaw: 0.6, ffx: 8, fbx: -6, fby: -6 }],
    ],
  },
  jump: { loop: false, poses: [[0, { ...G, yaw: 0.5, crouch: 0, ...AIRLEG }], [0.25, { ...G, yaw: 0.5, crouch: 0, ...AIRLEG }]] },
  fall: { loop: false, poses: [[0, { ...G, yaw: 0.5, crouch: 0, ffx: 5, ffy: -3, fbx: -5, fby: -6, fy: -30, by: -31 }], [0.25, { ...G, yaw: 0.5, crouch: 0, ffx: 5, ffy: -3, fbx: -5, fby: -6, fy: -30, by: -31 }]] },
  // 3타: 잽 → 스트레이트 → 어퍼컷(띄우기)
  atk1: {
    loop: false, poses: [
      [0, { ...G, yaw: 0.35, fx: 4, fy: -27 }],
      [0.06, { ...G, yaw: 0.25, lean: 4, fx: 18, fy: -28, ffx: 9, fbx: -8, ghost: 1 }, "snap"],
      [0.22, { ...G, yaw: 0.35, lean: 2, fx: 12, fy: -27 }],
    ],
  },
  atk2: {
    loop: false, poses: [
      [0, { ...G, yaw: 0.4, bx: 2, by: -27, armsFront: false }],
      [0.06, { ...G, yaw: 0.15, lean: 6, fx: 2, fy: -26, bx: 20, by: -29, armsFront: true, ffx: 11, fbx: -9, toeB: true, ghost: 1 }, "snap"],
      [0.22, { ...G, yaw: 0.25, lean: 4, bx: 15, by: -28, ffx: 10, fbx: -8 }],
    ],
  },
  atk3: {
    loop: false, poses: [
      [0, { ...G, yaw: 0.4, crouch: 8, lean: 5, fx: 8, fy: -14 }],
      [0.08, { ...G, yaw: 0.2, crouch: 0, lean: -3, fx: 11, fy: -44, bx: 4, by: -27, ffx: 7, fbx: -6, toeF: true, toeB: true, ghost: 1 }, "snap"],
      [0.32, { ...G, yaw: 0.3, crouch: 0, lean: -2, fx: 10, fy: -42, toeB: true }],
    ],
  },
  // 공중 연타 — 앞발 차기
  air: {
    loop: false, poses: [
      [0, { ...G, yaw: 0.3, crouch: 0, ...AIRLEG, ffx: 2, ffy: -14 }],
      [0.06, { ...G, yaw: 0.2, crouch: 0, lean: -5, fbx: -5, fby: -10, ffx: 19, ffy: -22, ghost: 1 }, "snap"],
      [0.2, { ...G, yaw: 0.3, crouch: 0, lean: -3, fbx: -5, fby: -10, ffx: 15, ffy: -19 }],
    ],
  },
  hurt: { loop: false, poses: [[0, { ...G, yaw: 0.6, lean: -7, crouch: 3, fx: 2, fy: -31, bx: 4, by: -33, hx: -2 }], [0.25, { ...G, yaw: 0.6, lean: -7, crouch: 3, fx: 2, fy: -31, bx: 4, by: -33 }]] },
  // 기술 다섯
  dash: {   // 날아차기
    loop: false, poses: [
      [0, { ...G, yaw: 0.4, crouch: 7, lean: 3, ffx: 4, fbx: -10 }],
      [0.1, { ...G, yaw: 0.1, crouch: 0, lean: -4, fx: -2, fy: -30, bx: 6, by: -31, ffx: 22, ffy: -16, fbx: -9, fby: -11, ghost: 1 }, "snap"],
      [0.4, { ...G, yaw: 0.15, crouch: 0, lean: -4, fx: -2, fy: -30, ffx: 21, ffy: -15, fbx: -9, fby: -11 }],
    ],
  },
  rise: {   // 회오리 차기 — 돌며 솟는다
    loop: false, poses: [
      [0, { ...G, yaw: 0.6, crouch: 8, lean: 3 }],
      [0.1, { ...G, yaw: 1.6, crouch: 0, ffx: 15, ffy: -26, fbx: -3, fby: -6, fx: -6, fy: -32, ghost: 1 }, "snap"],
      [0.2, { ...G, yaw: 3.14, crouch: 0, ffx: 15, ffy: -26, fbx: -3, fby: -6, fx: -6, fy: -32, ghost: 1 }],
      [0.3, { ...G, yaw: 4.7, crouch: 0, ffx: 15, ffy: -26, fbx: -3, fby: -6, fx: -6, fy: -32, ghost: 1 }],
      [0.42, { ...G, yaw: 6.28 + FRONT, crouch: 0, ...AIRLEG }],
    ],
  },
  wave: {   // 장풍 — 두 손바닥을 모아 앞으로
    loop: false, poses: [
      [0, { ...G, yaw: 0.6, crouch: 6, lean: -4, fx: -4, fy: -22, bx: -2, by: -24, armsFront: true }],
      [0.12, { ...G, yaw: 0.2, crouch: 4, lean: 6, fx: 19, fy: -25, bx: 19, by: -28, armsFront: true, ffx: 12, fbx: -10, ghost: 1 }, "snap"],
      [0.4, { ...G, yaw: 0.25, crouch: 4, lean: 5, fx: 18, fy: -25, bx: 18, by: -28, ffx: 12, fbx: -10 }],
    ],
  },
  stomp: {  // 땅 치기 — 뛰어올라 주먹으로 땅을 친다
    loop: false, poses: [
      [0, { ...G, yaw: 0.7, crouch: 0, lean: -5, fx: 4, fy: -46, bx: 7, by: -46, toeF: true, toeB: true }],
      [0.12, { ...G, yaw: 0.4, crouch: 10, lean: 9, fx: 13, fy: -2, bx: 10, by: -4, ffx: 9, fbx: -10, ghost: 1 }, "snap"],
      [0.42, { ...G, yaw: 0.45, crouch: 9, lean: 8, fx: 13, fy: -2, bx: 10, by: -4, ffx: 9, fbx: -10 }],
    ],
  },
  dive: {   // 내려찍기 — 공중에서 발꿈치로
    loop: false, poses: [
      [0, { ...G, yaw: 0.5, crouch: 0, ...AIRLEG, ffx: 4, ffy: -24 }],
      [0.08, { ...G, yaw: 0.3, crouch: 0, lean: 7, fx: 2, fy: -32, bx: 6, by: -33, ffx: 13, ffy: -3, fbx: -4, fby: -12, ghost: 1 }, "snap"],
      [0.3, { ...G, yaw: 0.3, crouch: 0, lean: 7, fx: 2, fy: -32, bx: 6, by: -33, ffx: 13, ffy: -3, fbx: -4, fby: -12 }],
    ],
  },
};
