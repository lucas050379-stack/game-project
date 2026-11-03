/**
 * 젤리팝 순위 · 플레이 기록 — 구글 시트에 붙이는 Apps Script.
 *
 * 붙이는 법(README "순위 서버"):
 *   1. 새 구글 시트 → 확장 프로그램 → Apps Script → 이 파일 내용을 통째로 붙여 넣고 저장
 *   2. 배포 → 새 배포 → 유형 "웹 앱" → 실행 계정 "나" · 액세스 권한 "모든 사용자" → 배포
 *   3. 나온 /exec 주소를 jellypop/rank_url.txt 에 한 줄로 저장하고 빌드
 *   코드를 고친 뒤에는 "배포 관리 → 수정 → 새 버전" 으로 올려야 같은 주소에 반영된다.
 *
 * 시트 탭 셋을 알아서 만든다:
 *   기록   판 하나가 끝날 때마다 한 줄 (난이도 확인용)
 *   순위   기기(uid)마다 한 줄 — 이름 · 타임 어택 최고 · 별 합 · 깬 판
 *   판별   메뉴 "젤리팝 → 판별 통계 만들기" 를 누르면 다시 계산
 *   판순위 (uid, 판)마다 최고 점수 한 줄 — 스테이지를 깬 결과 창의 순위
 *
 * 주소가 게임 안에 들어 있으므로 누구든 가짜 기록을 보낼 수 있다. 값의 범위만 막는다(지인 배포용).
 */

const LOG = '기록';
const RANK = '순위';
const STATS = '판별';
const LOG_HEAD = ['시각', 'uid', '이름', '종류', '판', '결과', '점수', '별', '남은이동', '이동', '시도', '초', '판본', '번호'];
const RANK_HEAD = ['uid', '이름', '타임어택', '별', '깬판', '갱신', '모험점수', '타임어택판'];
// 타임 어택 판본 — 게임의 Sv.TA_VER 와 같아야 한다. 다른 판본의 타임 어택 점수는 순위에서 뺀다(7×7 → 8×8).
const TA_VER = 2;
const MAX_STAGE = 200;
const STAGE_RANK = '판순위';
const STAGE_HEAD = ['열쇠', 'uid', '판', '점수', '갱신'];

/** 판마다 최고 점수. 열쇠(uid_판)로 한 줄을 찾아 더 높을 때만 고친다. */
function upsertStage(uid, stage, score) {
  const sh = stageSheet();
  const key = uid + '_' + stage;
  const hit = sh.getRange('A:A').createTextFinder(key).matchEntireCell(true).findNext();
  if (!hit) {
    sh.appendRow([key, uid, stage, score, new Date()]);
  } else if (score > Number(sh.getRange(hit.getRow(), 4).getValue())) {
    sh.getRange(hit.getRow(), 4, 1, 2).setValues([[score, new Date()]]);
  }
}

/** 그 판의 위 10명과 내 등수. 이름은 "순위" 탭에서 가져온다 — 이름을 바꾸면 옛 판 기록에도 따라간다. */
function stageBoard(stage, uid) {
  const rows = stageRows().filter(r => r[2] === stage);
  rows.sort((a, b) => Number(b[3]) - Number(a[3]));
  const names = {};
  rankRows().forEach(r => { names[r[0]] = String(r[1]); });
  const me = rows.findIndex(r => r[1] === uid);
  return { ok: true, stage: stage, total: rows.length, me: me < 0 ? 0 : me + 1,
    top: rows.slice(0, 10).map(r => [names[r[1]] || '이름없음', Number(r[3]), r[1] === uid]) };
}

function doPost(e) {
  const lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    const d = JSON.parse(e.postData.contents);
    const uid = String(d.uid || '').replace(/[^0-9a-f]/g, '').slice(0, 32);
    if (!uid) return out({ ok: false, err: 'uid' });
    const name = cleanName(d.name);
    const ver = String(d.ver || '').slice(0, 16);

    // 같은 사건을 두 번 받지 않는다 — 게임이 응답을 못 받으면 다시 보낸다
    const props = PropertiesService.getScriptProperties();
    const lastKey = 'q_' + uid;
    let last = Number(props.getProperty(lastKey) || 0);
    const rows = [];
    const wins = [];   // [판, 점수] — 판별 순위용
    for (const ev of (d.events || []).slice(0, 60)) {
      const q = int(ev.q, 0, 1e9);
      if (q <= last) continue;
      last = Math.max(last, q);
      const when = ev.at ? new Date(int(ev.at, 0, 4e9) * 1000) : new Date();
      if (ev.k === 'ta') {
        rows.push([when, uid, name, '타임어택', '', '', int(ev.sc, 0, 1e7), '', '', '', '', '', ver, q]);
      } else if (ev.k === 'st') {
        const r = { win: '성공', lose: '실패', quit: '포기' }[ev.r] || '?';
        rows.push([when, uid, name, '모험', int(ev.s, 1, MAX_STAGE), r, int(ev.sc, 0, 1e7), int(ev.st, 0, 3),
          int(ev.ml, 0, 99), int(ev.mv, 0, 99), int(ev.tr, 0, 9999), int(ev.sec, 0, 36000), ver, q]);
        if (ev.r === 'win') wins.push([int(ev.s, 1, MAX_STAGE), int(ev.sc, 0, 1e7)]);
      }
    }
    if (rows.length) {
      const log = sheet(LOG, LOG_HEAD);
      log.getRange(log.getLastRow() + 1, 1, rows.length, LOG_HEAD.length).setValues(rows);
    }
    props.setProperty(lastKey, String(last));

    // 개발용(-dev) 판본은 순위에 안 올린다
    if (ver.indexOf('dev') < 0) {
      const s = d.snap || {};
      upsertRank(uid, name, int(s.tav, 0, 99) === TA_VER ? int(s.ta, 0, 1e7) : 0, int(s.stars, 0, MAX_STAGE * 3), int(s.cleared, 0, MAX_STAGE),
        int(s.score, 0, 1e9));
      for (const w of wins) upsertStage(uid, w[0], w[1]);
    }
    CacheService.getScriptCache().removeAll(['rank_rows', 'stage_rows']);
    return out({ ok: true });
  } catch (err) {
    return out({ ok: false, err: String(err) });
  } finally {
    lock.releaseLock();
  }
}

function doGet(e) {
  const mode = (e.parameter && e.parameter.mode) || 'rank';
  if (mode === 'stats') return out({ ok: true, stages: stageStats() });
  if (mode === 'stage') return out(stageBoard(int(e.parameter.s, 1, MAX_STAGE), String(e.parameter.uid || '')));
  const uid = String((e.parameter && e.parameter.uid) || '');
  const data = rankRows();
  const board = (col) => {
    const list = data.filter(r => Number(r[col]) > 0).sort((a, b) => Number(b[col]) - Number(a[col]));
    const top = list.slice(0, 30).map(r => [String(r[1]), Number(r[col]), r[0] === uid]);
    const me = list.findIndex(r => r[0] === uid);
    return { top: top, me: me < 0 ? 0 : me + 1, total: list.length };
  };
  return out({ ok: true, ta: board(2), stars: board(3), adv: board(6) });
}

function upsertRank(uid, name, ta, stars, cleared, score) {
  const sh0 = sheet(RANK, RANK_HEAD);
  // 예전 시트는 칸이 적다(모험점수 · 타임어택판) — 머리줄을 새로 쓴다
  if (sh0.getLastColumn() < RANK_HEAD.length) sh0.getRange(1, 1, 1, RANK_HEAD.length).setValues([RANK_HEAD]);
  const sh = sheet(RANK, RANK_HEAD);
  const hit = sh.getRange('A:A').createTextFinder(uid).matchEntireCell(true).findNext();
  if (hit) {
    const row = hit.getRow();
    const old = sh.getRange(row, 1, 1, RANK_HEAD.length).getValues()[0];
    const oldTa = Number(old[7]) === TA_VER ? (Number(old[2]) || 0) : 0;
    sh.getRange(row, 1, 1, RANK_HEAD.length).setValues([[uid, name, Math.max(ta, oldTa),
      stars, cleared, new Date(), Math.max(score, Number(old[6]) || 0), TA_VER]]);
  } else {
    sh.appendRow([uid, name, ta, stars, cleared, new Date(), score, TA_VER]);
  }
}

/** 판마다 시도 · 성공 · 포기 · 성공률 · 이긴 판의 평균 남은 이동. 개발용(-dev) 기록은 뺀다. */
function stageStats() {
  const sh = sheet(LOG, LOG_HEAD);
  const n = sh.getLastRow() - 1;
  if (n <= 0) return [];
  const rows = sh.getRange(2, 1, n, LOG_HEAD.length).getValues();
  const st = {};
  for (const r of rows) {
    if (r[3] !== '모험' || String(r[12]).indexOf('dev') >= 0) continue;
    const id = Number(r[4]);
    const s = st[id] || (st[id] = { stage: id, plays: 0, win: 0, lose: 0, quit: 0, left: 0, players: {} });
    s.plays++;
    s.players[r[1]] = true;
    if (r[5] === '성공') { s.win++; s.left += Number(r[8]) || 0; }
    else if (r[5] === '실패') s.lose++;
    else if (r[5] === '포기') s.quit++;
  }
  return Object.keys(st).map(Number).sort((a, b) => a - b).map(id => {
    const s = st[id];
    return { stage: id, plays: s.plays, players: Object.keys(s.players).length, win: s.win, lose: s.lose,
      quit: s.quit, rate: s.plays ? Math.round(s.win / s.plays * 1000) / 10 : 0,
      left: s.win ? Math.round(s.left / s.win * 10) / 10 : 0 };
  });
}

/** 메뉴: 판별 통계를 시트 탭으로 */
function makeStats() {
  const list = stageStats();
  const head = ['판', '시도', '사람', '성공', '실패', '포기', '성공률%', '평균남은이동'];
  const sh = sheet(STATS, head);
  if (sh.getLastRow() > 1) sh.getRange(2, 1, sh.getLastRow() - 1, head.length).clearContent();
  if (list.length) {
    sh.getRange(2, 1, list.length, head.length).setValues(list.map(s =>
      [s.stage, s.plays, s.players, s.win, s.lose, s.quit, s.rate, s.left]));
  }
}

function onOpen() {
  SpreadsheetApp.getUi().createMenu('젤리팝').addItem('판별 통계 만들기', 'makeStats').addToUi();
}

function sheet(name, head) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(name);
  if (!sh) {
    sh = ss.insertSheet(name);
    sh.appendRow(head);
    sh.setFrozenRows(1);
  }
  return sh;
}

function cleanName(s) {
  // 맨 앞 = + - @ 는 시트가 수식으로 읽는다
  s = String(s || '').replace(/[\u0000-\u001f<>]/g, '').trim().replace(/^[=+\-@]+/, '').slice(0, 10);
  return s || '이름없음';
}

function int(v, lo, hi) {
  const n = Math.floor(Number(v) || 0);
  return Math.min(hi, Math.max(lo, n));
}

function out(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

/** "판순위" 탭. 처음 만들 때 "기록" 탭의 지난 성공 기록으로 채운다 — 이 탭이 생기기 전에 깬 판도 순위에 오르게. */
function stageSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  if (ss.getSheetByName(STAGE_RANK)) return ss.getSheetByName(STAGE_RANK);
  const sh = sheet(STAGE_RANK, STAGE_HEAD);
  const log = sheet(LOG, LOG_HEAD);
  const n = log.getLastRow() - 1;
  if (n <= 0) return sh;
  const best = {};
  for (const r of log.getRange(2, 1, n, LOG_HEAD.length).getValues()) {
    if (r[3] !== '모험' || r[5] !== '성공' || String(r[12]).indexOf('dev') >= 0) continue;
    const key = r[1] + '_' + Number(r[4]);
    if (!best[key] || Number(r[6]) > best[key][3]) best[key] = [key, r[1], Number(r[4]), Number(r[6]), new Date()];
  }
  const rows = Object.keys(best).map(k => best[k]);
  if (rows.length) sh.getRange(2, 1, rows.length, STAGE_HEAD.length).setValues(rows);
  return sh;
}

// ==================== 캐시 ====================
// 순위를 물을 때마다 탭을 통째로 읽으면 느리다. 읽은 것을 10분 캐시에 두고, 기록이 들어오면(doPost) 지운다.
// 캐시 한 칸은 100KB 까지라 넘으면 그냥 매번 읽는다(지인 규모에서는 안 넘는다).

function cached(key, read) {
  const c = CacheService.getScriptCache();
  const hit = c.get(key);
  if (hit) return JSON.parse(hit);
  const rows = read();
  const s = JSON.stringify(rows);
  if (s.length < 95000) c.put(key, s, 600);
  return rows;
}

/** 순위 탭 — [uid, 이름, 타임어택, 별, 깬판, (갱신 자리), 모험점수] */
function rankRows() {
  return cached('rank_rows', () => {
    const sh = sheet(RANK, RANK_HEAD);
    const n = sh.getLastRow() - 1;
    if (n <= 0) return [];
    return sh.getRange(2, 1, n, RANK_HEAD.length).getValues().map(r =>
      [String(r[0]), String(r[1]), Number(r[7]) === TA_VER ? (Number(r[2]) || 0) : 0, Number(r[3]) || 0,
        Number(r[4]) || 0, 0, Number(r[6]) || 0]);
  });
}

/** 판순위 탭 — [열쇠, uid, 판, 점수] */
function stageRows() {
  return cached('stage_rows', () => {
    const sh = stageSheet();
    const n = sh.getLastRow() - 1;
    if (n <= 0) return [];
    return sh.getRange(2, 1, n, 4).getValues().map(r => [String(r[0]), String(r[1]), Number(r[2]), Number(r[3])]);
  });
}
