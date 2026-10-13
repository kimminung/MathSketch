// MathSketch 소개 영상 — 결정적(deterministic) 타임라인.
// window.renderFrame(t) 가 t초 시점의 프레임 하나를 1920×1080 캔버스에 그린다 (render.js 가 프레임 단위로 캡처).
// 화면 속 도형·수식·색 이름은 모두 engine.js(앱 Swift 코드 포트)가 계산한 값이다 — 손으로 쓴 수식 없음.
'use strict';
const W = 1920, H = 1080, TAU = Math.PI * 2;
const cv = document.getElementById('c');
const ctx = cv.getContext('2d');

// ───────────────────────── 색 · 글꼴
const INK = '#111111', GRAY = '#6E6E73', GRAY2 = '#8E8E93', LIGHT = '#C7C7CC', FAINT = '#E5E5EA', PANEL = '#F2F2F7';
const BLUE = '#007AFF', RED = '#FF3B30', CHARCOAL = '#1C1C1E';
const BR1 = '#3D196B', BR2 = '#C3266C', BR3 = '#FF6B35'; // 앱 아이콘 그라디언트(보라 → 자홍 → 주황)
const CANVAS_BG = 'rgba(142,142,147,0.08)';               // Color.gray.opacity(0.08)
const F_KR = '"Noto Sans CJK KR"';
const F_EN = 'Inter, "Noto Sans CJK KR"';
const F_MONO = '"DejaVu Sans Mono", "Latin Modern Math", "Noto Sans CJK KR"';
const F_MATH = '"Latin Modern Math", "DejaVu Serif", "Noto Serif CJK KR"';

// ───────────────────────── 유틸
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const prog = (t, a, b) => clamp((t - a) / (b - a), 0, 1);
const eOut = t => 1 - Math.pow(1 - t, 3);
const eIn = t => t * t * t;
const eIO = t => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
const eBack = t => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); };
// a~b 구간에서 fi 동안 나타나고 fo 동안 사라지는 불투명도
function win(t, a, b, fi = 0.35, fo = 0.35) {
  if (t < a || t > b) return 0;
  return Math.min(fi > 0 ? eOut(prog(t, a, a + fi)) : 1, fo > 0 ? 1 - eIn(prog(t, b - fo, b)) : 1);
}
const hex2rgb = h => { h = h.replace('#', ''); return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16)); };
const mix = (a, b, t) => '#' + hex2rgb(a).map((v, i) => Math.round(lerp(v, hex2rgb(b)[i], t)).toString(16).padStart(2, '0')).join('');
function rr(x, y, w, h, r) { ctx.beginPath(); ctx.roundRect(x, y, w, h, Math.max(0, Math.min(r, w / 2, h / 2))); }
function font(size, weight = 400, fam = F_KR, style = '') { return `${style} ${weight} ${size}px ${fam}`.trim(); }
function measure(str, size, weight = 400, fam = F_KR, style = '') { ctx.font = font(size, weight, fam, style); return ctx.measureText(str).width; }
function text(str, x, y, o = {}) {
  const { size = 32, weight = 400, fam = F_KR, color = INK, align = 'left', alpha = 1, base = 'alphabetic', ls = 0, style = '' } = o;
  if (alpha <= 0 || !str) return;
  ctx.save(); ctx.globalAlpha *= alpha; ctx.fillStyle = color; ctx.font = font(size, weight, fam, style);
  ctx.textAlign = align; ctx.textBaseline = base; if (ls) ctx.letterSpacing = ls + 'px';
  ctx.fillText(str, x, y); ctx.restore();
}
// 공백 단위 줄바꿈(너무 긴 토큰은 글자 단위로 자름)
function wrapLines(str, maxW, size, weight = 400, fam = F_KR) {
  ctx.font = font(size, weight, fam);
  const words = str.split(' '); const lines = []; let cur = null;
  for (const w of words) {
    const cand = cur === null ? w : cur + ' ' + w;
    if (cur === null || ctx.measureText(cand).width <= maxW) cur = cand; else { lines.push(cur); cur = w; }
  }
  if (cur !== null) lines.push(cur);
  const out = [];
  for (let l of lines) {
    l = l.replace(/^ +/, (m) => (out.length === 0 ? m : ''));
    if (ctx.measureText(l).width <= maxW) { out.push(l); continue; }
    let s = '';
    for (const ch of Array.from(l)) { if (s && ctx.measureText(s + ch).width > maxW) { out.push(s); s = ch; } else s += ch; }
    if (s) out.push(s);
  }
  return out;
}
function brandGrad(x0, y0, x1, y1) { const g = ctx.createLinearGradient(x0, y0, x1, y1); g.addColorStop(0, BR1); g.addColorStop(0.55, BR2); g.addColorStop(1, BR3); return g; }
function shadow(blur = 30, dy = 10, a = 0.12) { ctx.shadowColor = `rgba(0,0,0,${a})`; ctx.shadowBlur = blur; ctx.shadowOffsetY = dy; }
// 장면 전환: 장면을 불투명하게 그린 뒤 흰 막을 덮는다(겹친 요소가 비쳐 보이지 않게)
function fadeOverlay(a, rect) {
  if (a >= 1) return;
  ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalAlpha = 1; ctx.fillStyle = `rgba(255,255,255,${1 - a})`;
  if (rect) ctx.fillRect(rect.x, rect.y, rect.w, rect.h); else ctx.fillRect(0, 0, W, H);
  ctx.restore();
}
function noShadow() { ctx.shadowColor = 'transparent'; ctx.shadowBlur = 0; ctx.shadowOffsetY = 0; }

// ───────────────────────── 경로 그리기 (호 길이 기준 부분 그리기)
function tracePartial(pts, closed, p) {
  const P = closed ? pts.concat([pts[0]]) : pts;
  const acc = [0];
  for (let i = 1; i < P.length; i++) acc.push(acc[i - 1] + Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]));
  const target = acc[acc.length - 1] * clamp(p, 0, 1);
  ctx.beginPath(); ctx.moveTo(P[0][0], P[0][1]);
  for (let i = 1; i < P.length; i++) {
    if (acc[i] <= target) ctx.lineTo(P[i][0], P[i][1]);
    else { const seg = acc[i] - acc[i - 1]; const f = seg > 0 ? (target - acc[i - 1]) / seg : 0; ctx.lineTo(lerp(P[i - 1][0], P[i][0], f), lerp(P[i - 1][1], P[i][1], f)); break; }
  }
  if (closed && p >= 1) ctx.closePath();
}
// SketchDrawing.draw 와 같은 규칙: point = 채운 원(r 6), plane = 채움, 나머지 = 선(선택 시 굵게)
function drawItem(it, o = {}) {
  const { lw = 2, pointR = 6, color = it.el.color, alpha = 1, progress = 1, selected = false } = o;
  if (alpha <= 0 || progress <= 0) return;
  const style = MS.renderStyle(it.el.kind);
  ctx.save(); ctx.globalAlpha *= alpha; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  if (style === 'point') {
    const [x, y] = it.pts[0]; ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x, y, pointR * Math.max(0, eBack(progress)), 0, TAU); ctx.fill();
  } else if (style === 'fill') {
    ctx.globalAlpha *= progress;
    ctx.beginPath(); ctx.moveTo(it.pts[0][0], it.pts[0][1]); for (const p of it.pts.slice(1)) ctx.lineTo(p[0], p[1]); ctx.closePath();
    ctx.fillStyle = color; ctx.fill();
    if (selected) { ctx.strokeStyle = BLUE; ctx.lineWidth = lw; ctx.stroke(); }
  } else {
    tracePartial(it.pts, MS.isClosed(it.el.kind), progress);
    ctx.strokeStyle = color; ctx.lineWidth = selected ? lw * 1.5 : lw; ctx.stroke();
  }
  ctx.restore();
}
// 캔버스 카드 — SketchCanvasRenderer.fit 그대로(공통 바운딩박스 → 뷰 0.92 맞춤)
function canvasCard(rect, elements, o = {}) {
  const S = o.S || 1;
  if ((o.alpha ?? 1) <= 0) return null;
  ctx.save(); ctx.globalAlpha *= (o.alpha ?? 1);
  if (o.shadow) { shadow(40, 14, 0.10); rr(rect.x, rect.y, rect.w, rect.h, 16 * S); ctx.fillStyle = '#fff'; ctx.fill(); noShadow(); }
  rr(rect.x, rect.y, rect.w, rect.h, 16 * S); ctx.fillStyle = o.bg || CANVAS_BG; ctx.fill();
  ctx.save(); rr(rect.x, rect.y, rect.w, rect.h, 16 * S); ctx.clip();
  const fitted = MS.fit(elements, rect, 128, o.fitCtx);
  for (const it of fitted) {
    drawItem(it, {
      lw: o.lw || 2 * S, pointR: 6 * S,
      color: o.colorOf ? o.colorOf(it.el) : it.el.color,
      alpha: o.alphaOf ? o.alphaOf(it.el) : 1,
      progress: o.progressOf ? o.progressOf(it.el) : 1,
      selected: it.el.id === o.selectedId,
    });
  }
  if (o.selectedId) for (const it of fitted) if (it.el.id === o.selectedId) {
    const b = MS.bbox(it.pts);
    ctx.save(); ctx.globalAlpha *= (o.selAlpha ?? 1); ctx.setLineDash([5 * S, 4 * S]); ctx.strokeStyle = BLUE; ctx.lineWidth = 1.5 * S;
    ctx.strokeRect(b.x - 8 * S, b.y - 8 * S, Math.max(b.w, 1) + 16 * S, Math.max(b.h, 1) + 16 * S); ctx.restore();
  }
  ctx.restore(); ctx.restore();
  return fitted;
}

// ───────────────────────── 공통 UI 조각
function header(num, title, sub, alpha) {
  if (alpha <= 0) return;
  const x = 120, y = 178;
  ctx.save(); ctx.globalAlpha *= alpha;
  ctx.font = font(26, 700, F_EN); ctx.letterSpacing = '6px'; ctx.textBaseline = 'alphabetic';
  const nw = ctx.measureText(num).width; ctx.fillStyle = brandGrad(x, 0, x + nw, 0); ctx.fillText(num, x, y - 84); ctx.letterSpacing = '0px';
  text(title, x, y, { size: 72, weight: 700 });
  if (sub) text(sub, x + measure(title, 72, 700) + 34, y - 2, { size: 34, color: GRAY });
  ctx.restore();
}
function caption(str, alpha, y = 1018) { text(str, 120, y, { size: 28, color: GRAY, alpha }); }
// 여러 캡션을 시간에 따라 교차 페이드
function captions(t, list, y) {
  for (const [a, b, str] of list) { const al = win(t, a, b, 0.3, 0.3); if (al > 0) caption(str, al, y); }
}
function finger(x, y, alpha = 1, press = 0) {
  if (alpha <= 0) return;
  ctx.save(); ctx.globalAlpha *= alpha;
  const r = 30 - 5 * press;
  shadow(16, 4, 0.16);
  ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fillStyle = `rgba(255,255,255,${0.5 + 0.25 * press})`; ctx.fill(); noShadow();
  ctx.lineWidth = 2.5; ctx.strokeStyle = 'rgba(60,60,67,0.42)'; ctx.stroke();
  if (press > 0) { ctx.beginPath(); ctx.arc(x, y, r * 0.5 * press, 0, TAU); ctx.fillStyle = 'rgba(60,60,67,0.22)'; ctx.fill(); }
  ctx.restore();
}
function pill(x, y, label, o = {}) { // 작은 설명 배지
  const { alpha = 1, size = 24, color = INK, bg = '#fff', icon = null } = o;
  if (alpha <= 0) return 0;
  const w = measure(label, size, 600) + 40 + (icon ? size + 8 : 0), h = size + 22;
  ctx.save(); ctx.globalAlpha *= alpha; shadow(18, 6, 0.10); rr(x, y, w, h, h / 2); ctx.fillStyle = bg; ctx.fill(); noShadow();
  let cx = x + 20;
  if (icon) { icon(cx + size / 2, y + h / 2, size); cx += size + 8; }
  text(label, cx, y + h / 2 + size * 0.36, { size, weight: 600, color }); ctx.restore();
  return w;
}

// ───────────────────────── SF Symbols 근사 아이콘 (선 그림)
function iconStroke(c = BLUE, lw = 2) { ctx.strokeStyle = c; ctx.fillStyle = c; ctx.lineWidth = lw; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; }
const ICON = {
  copy(x, y, s, c = BLUE) { ctx.save(); iconStroke(c, s * 0.09); rr(x - s * 0.18, y - s * 0.3, s * 0.48, s * 0.56, s * 0.08); ctx.stroke(); ctx.beginPath(); ctx.moveTo(x - s * 0.3, y - s * 0.12); ctx.lineTo(x - s * 0.3, y + s * 0.38); ctx.lineTo(x + s * 0.12, y + s * 0.38); ctx.stroke(); ctx.restore(); },
  fx(x, y, s, c = BLUE) { text('f(x)', x, y + s * 0.3, { size: s * 0.8, weight: 500, fam: F_MATH, style: 'italic', color: c, align: 'center' }); },
  trash(x, y, s, c = RED) { ctx.save(); iconStroke(c, s * 0.08); ctx.beginPath(); ctx.moveTo(x - s * 0.36, y - s * 0.26); ctx.lineTo(x + s * 0.36, y - s * 0.26); ctx.stroke(); ctx.beginPath(); ctx.moveTo(x - s * 0.12, y - s * 0.26); ctx.lineTo(x - s * 0.1, y - s * 0.38); ctx.lineTo(x + s * 0.1, y - s * 0.38); ctx.lineTo(x + s * 0.12, y - s * 0.26); ctx.stroke(); ctx.beginPath(); ctx.moveTo(x - s * 0.27, y - s * 0.2); ctx.lineTo(x - s * 0.22, y + s * 0.38); ctx.lineTo(x + s * 0.22, y + s * 0.38); ctx.lineTo(x + s * 0.27, y - s * 0.2); ctx.stroke(); ctx.restore(); },
  xmark(x, y, s, c = GRAY2) { ctx.save(); ctx.fillStyle = c; ctx.globalAlpha *= 0.55; ctx.beginPath(); ctx.arc(x, y, s * 0.42, 0, TAU); ctx.fill(); ctx.globalAlpha /= 0.55; iconStroke('#fff', s * 0.09); const d = s * 0.15; ctx.beginPath(); ctx.moveTo(x - d, y - d); ctx.lineTo(x + d, y + d); ctx.moveTo(x + d, y - d); ctx.lineTo(x - d, y + d); ctx.stroke(); ctx.restore(); },
  chevronDown(x, y, s, c = INK) { ctx.save(); iconStroke(c, s * 0.11); ctx.beginPath(); ctx.moveTo(x - s * 0.22, y - s * 0.1); ctx.lineTo(x, y + s * 0.12); ctx.lineTo(x + s * 0.22, y - s * 0.1); ctx.stroke(); ctx.restore(); },
  undo(x, y, s, c = INK) { ctx.save(); iconStroke(c, s * 0.09); ctx.beginPath(); ctx.arc(x + s * 0.04, y + s * 0.06, s * 0.26, Math.PI * 1.05, Math.PI * 0.45, false); ctx.stroke(); ctx.beginPath(); ctx.moveTo(x - s * 0.34, y - s * 0.16); ctx.lineTo(x - s * 0.22, y + s * 0.06); ctx.lineTo(x - s * 0.02, y - s * 0.06); ctx.stroke(); ctx.restore(); },
  redo(x, y, s, c = INK) { ctx.save(); ctx.translate(x, y); ctx.scale(-1, 1); ICON.undo(0, 0, s, c); ctx.restore(); },
  save(x, y, s, c = INK) { ctx.save(); iconStroke(c, s * 0.08); ctx.beginPath(); ctx.moveTo(x, y - s * 0.38); ctx.lineTo(x, y + s * 0.12); ctx.moveTo(x - s * 0.17, y - s * 0.05); ctx.lineTo(x, y + s * 0.12); ctx.lineTo(x + s * 0.17, y - s * 0.05); ctx.stroke(); ctx.beginPath(); ctx.moveTo(x - s * 0.14, y - s * 0.2); ctx.lineTo(x - s * 0.34, y - s * 0.2); ctx.lineTo(x - s * 0.34, y + s * 0.36); ctx.lineTo(x + s * 0.34, y + s * 0.36); ctx.lineTo(x + s * 0.34, y - s * 0.2); ctx.lineTo(x + s * 0.14, y - s * 0.2); ctx.stroke(); ctx.restore(); },
  colorWell(x, y, s, fill) { ctx.save(); const g = ctx.createConicGradient(0, x, y); ['#FF3B30', '#FF9500', '#FFCC00', '#34C759', '#00C7BE', '#007AFF', '#AF52DE', '#FF2D55', '#FF3B30'].forEach((c, i, a) => g.addColorStop(i / (a.length - 1), c)); ctx.beginPath(); ctx.arc(x, y, s * 0.5, 0, TAU); ctx.fillStyle = g; ctx.fill(); ctx.beginPath(); ctx.arc(x, y, s * 0.38, 0, TAU); ctx.fillStyle = '#fff'; ctx.fill(); ctx.beginPath(); ctx.arc(x, y, s * 0.31, 0, TAU); ctx.fillStyle = fill; ctx.fill(); ctx.restore(); },
  canvasTab(x, y, s, c) { ctx.save(); ctx.fillStyle = c; ctx.beginPath(); ctx.arc(x - s * 0.12, y - s * 0.1, s * 0.26, 0, TAU); ctx.fill(); ctx.globalCompositeOperation = 'source-over'; rr(x - s * 0.06, y - s * 0.04, s * 0.42, s * 0.42, s * 0.06); ctx.fill(); ctx.restore(); },
  galleryTab(x, y, s, c) { ctx.save(); iconStroke(c, s * 0.08); rr(x - s * 0.34, y - s * 0.22, s * 0.68, s * 0.5, s * 0.06); ctx.stroke(); ctx.beginPath(); ctx.moveTo(x - s * 0.26, y + s * 0.2); ctx.lineTo(x - s * 0.05, y - s * 0.02); ctx.lineTo(x + s * 0.08, y + s * 0.1); ctx.lineTo(x + s * 0.18, y + s * 0.02); ctx.lineTo(x + s * 0.28, y + s * 0.2); ctx.stroke(); ctx.beginPath(); ctx.arc(x + s * 0.12, y - s * 0.08, s * 0.05, 0, TAU); ctx.fill(); ctx.beginPath(); ctx.moveTo(x - s * 0.26, y - s * 0.32); ctx.lineTo(x + s * 0.4, y - s * 0.32); ctx.lineTo(x + s * 0.4, y + s * 0.14); ctx.stroke(); ctx.restore(); },
};

// ───────────────────────── 앱 컴포넌트 (확대 재현)
// PaletteChip: 64×72 + padding 6, 44×44 미리보기, caption2 이름 (PaletteView.swift)
function chip(kind, x, y, S, o = {}) {
  const w = 76 * S, h = 84 * S;
  ctx.save(); ctx.globalAlpha *= (o.alpha ?? 1);
  const sc = o.scale ?? 1;
  if (sc !== 1) { ctx.translate(x + w / 2, y + h / 2); ctx.scale(sc, sc); ctx.translate(-(x + w / 2), -(y + h / 2)); }
  if (o.lift) { shadow(24 * o.lift, 10 * o.lift, 0.18 * o.lift); }
  rr(x, y, w, h, 10 * S); ctx.fillStyle = o.bg || '#EEEEF1'; ctx.fill(); noShadow();
  if (o.ring) { ctx.lineWidth = 2.5; ctx.strokeStyle = BLUE; ctx.globalAlpha *= o.ring; rr(x, y, w, h, 10 * S); ctx.stroke(); ctx.globalAlpha /= o.ring; }
  const cx = x + 16 * S, cy = y + 10 * S;
  const rect = { x: cx + 5 * S, y: cy + 5 * S, w: 34 * S, h: 34 * S };
  ctx.save(); ctx.beginPath(); ctx.rect(cx, cy, 44 * S, 44 * S); ctx.clip();
  for (const it of MS.fit([MS.element(kind, { color: o.color || CHARCOAL })], rect)) drawItem(it, { lw: 2 * S * 0.8, pointR: 6 * S * 0.8 });
  ctx.restore();
  let label = MS.DISPLAY_NAME[kind]; let fs = 11 * S;
  const maxW = 64 * S; const lw = measure(label, fs, 400); if (lw > maxW) fs *= Math.max(0.8, maxW / lw);
  text(label, x + w / 2, y + 68 * S, { size: fs, align: 'center', color: INK });
  ctx.restore();
}
// iOS 슬라이더 (InspectorView.sliderRow)
function sliderRow(x, y, w, S, title, value, min, max, suffix, o = {}) {
  const rowH = 30 * S, cy = y + rowH / 2;
  text(title, x, cy + 6 * S, { size: 13 * S, color: INK });
  const tx0 = x + 72 * S, tx1 = x + w - 60 * S, tw = tx1 - tx0;
  const f = clamp((value - min) / (max - min), 0, 1);
  rr(tx0, cy - 3 * S, tw, 6 * S, 3 * S); ctx.fillStyle = '#E3E3E8'; ctx.fill();
  rr(tx0, cy - 3 * S, Math.max(6 * S, tw * f), 6 * S, 3 * S); ctx.fillStyle = BLUE; ctx.fill();
  const thx = tx0 + tw * f, act = o.active || 0;
  const tW = (36 + 10 * act) * S, tH = (22 + 4 * act) * S;
  ctx.save(); shadow(10 * S, 2 * S, 0.22); rr(thx - tW / 2, cy - tH / 2, tW, tH, tH / 2); ctx.fillStyle = '#fff'; ctx.fill(); noShadow(); ctx.restore();
  if (act > 0) { ctx.save(); ctx.globalAlpha *= act; ctx.lineWidth = 1.5; ctx.strokeStyle = 'rgba(0,122,255,0.55)'; rr(thx - tW / 2, cy - tH / 2, tW, tH, tH / 2); ctx.stroke(); ctx.restore(); }
  text(MS.fmt(value) + suffix, x + w, cy + 6 * S, { size: 13 * S, align: 'right', fam: F_EN, weight: act > 0 ? 600 : 400, color: act > 0 ? BLUE : INK });
  return { thumb: [thx, cy], rowH };
}
// 수식 라벨 줄 그리기 — 지금 바뀌고 있는 변형 항(rotate(…) 등)만 파란색으로 강조
function drawLabelLines(lines, x, y0, size, lh, token) {
  let inTok = false;
  lines.forEach((line, li) => {
    let cx = x, seg = '', segOn = inTok;
    const y = y0 + li * lh;
    const flush = () => { if (!seg) return; const wgt = segOn ? 700 : 400; text(seg, cx, y, { size, fam: F_MONO, weight: wgt, color: segOn ? BLUE : GRAY }); cx += measure(seg, size, wgt, F_MONO); seg = ''; };
    for (let i = 0; i < line.length; i++) {
      if (!inTok && token && line.startsWith(token + '(', i)) { flush(); inTok = true; segOn = true; }
      seg += line[i];
      if (inTok && line[i] === ')') { flush(); inTok = false; segOn = false; }
    }
    flush();
  });
}
// InspectorView (펼친 상태): 이름 + 수식 라벨(모노) + 슬라이더 5개 + 색상
function inspector(x, y, w, S, st, alpha = 1) {
  if (alpha <= 0) return null;
  const pad = 16 * S, iw = w - pad * 2;
  const labelSize = 13.5 * S;
  const lines = wrapLines(st.label, iw, labelSize, 400, F_MONO).slice(0, 4);
  const hdrH = 44 * S, gap = 8 * S, rowH = 30 * S;
  const h = pad + hdrH + gap + lines.length * labelSize * 1.38 + gap + 5 * (rowH + gap) + 30 * S + pad;
  ctx.save(); ctx.globalAlpha *= alpha;
  shadow(40, 14, 0.10); rr(x, y, w, h, 14 * S); ctx.fillStyle = '#F4F4F7'; ctx.fill(); noShadow();
  let cy = y + pad;
  ICON.chevronDown(x + pad + 8 * S, cy + hdrH / 2, 22 * S);
  text(st.name, x + pad + 24 * S, cy + hdrH / 2 + 6 * S, { size: 17 * S, weight: 700 });
  ICON.trash(x + w - pad - 52 * S, cy + hdrH / 2, 26 * S);
  ICON.xmark(x + w - pad - 12 * S, cy + hdrH / 2, 30 * S);
  const xmarkPos = [x + w - pad - 12 * S, cy + hdrH / 2];
  cy += hdrH + gap;
  drawLabelLines(lines, x + pad, cy + labelSize, labelSize, labelSize * 1.38, st.token);
  cy += lines.length * labelSize * 1.38 + gap;
  const v = st.vals, A = st.active || {};
  const rows = [['스케일 X', v.sx, 0.1, 8, '', 'sx'], ['스케일 Y', v.sy, 0.1, 8, '', 'sy'], ['회전', v.rot, -180, 180, '°', 'rot'], ['비틀기 X', v.shx, -1, 1, '', 'shx'], ['비틀기 Y', v.shy, -1, 1, '', 'shy']];
  const thumbs = {};
  for (const [title, val, mn, mx, suf, key] of rows) { const r = sliderRow(x + pad, cy, iw, S, title, val, mn, mx, suf, { active: A[key] || 0 }); thumbs[key] = r.thumb; cy += rowH + gap; }
  text('색상 (장식 전용, 수식에 포함되지 않음)', x + pad, cy + 20 * S, { size: 13 * S });
  ICON.colorWell(x + w - pad - 14 * S, cy + 15 * S, 28 * S, st.color);
  if (A.color) { ctx.save(); ctx.globalAlpha *= A.color; ctx.lineWidth = 3; ctx.strokeStyle = BLUE; ctx.beginPath(); ctx.arc(x + w - pad - 14 * S, cy + 15 * S, 20 * S, 0, TAU); ctx.stroke(); ctx.restore(); }
  const colorPos = [x + w - pad - 14 * S, cy + 15 * S];
  ctx.restore();
  return { h, thumbs, colorPos, xmarkPos };
}

// ───────────────────────── 그림 데이터
// 영상에서 조립하는 "해 질 녘 바다". 값은 앱에서 제스처/슬라이더로 만든 것처럼 소수 셋째 자리까지.
const C = { orange: '#FF6B35', topaz: '#FFC94A', sky: '#4FA3D1', indigo: '#1E3A8A', magenta: '#C2185B', charcoal: '#36454F', plum: '#6B3FA0' };
const PEAK_FINAL = { sx: 1.807, sy: 1.394, rot: 179.4, shx: -0.402, shy: 0, tx: -80.263, ty: 2.418 };
const PEAK_DROP = [-92.517, 31.684];
function baseComposition() {
  return [
    MS.element('circle', { id: 'sun', z: 0, t: { sx: 0.362, sy: 0.362, tx: 1.284, ty: 40.517 }, color: C.orange }),
    MS.element('hypocycloid', { id: 'corona', z: 1, t: { sx: 0.853, sy: 0.853, tx: 0.917, ty: 40.203 }, color: C.topaz }),
    MS.element('sine', { id: 'wave1', z: 2, t: { sx: 3.594, sy: 0.221, tx: -0.736, ty: -36.148 }, color: C.sky }),
    MS.element('sine', { id: 'wave2', z: 3, t: { sx: 3.594, sy: 0.221, tx: 20.312, ty: -52.407 }, color: C.indigo }),
    MS.element('polyline', { id: 'hill', z: 4, t: { sx: 1.203, sy: 0.897, rot: 179.6, shx: 0.304, tx: 40.588, ty: -8.214 }, color: C.magenta }),
    MS.element('arc', { id: 'bird1', z: 5, t: { sx: 0.121, sy: 0.083, tx: 70.122, ty: 100.36 }, color: C.charcoal }),
    MS.element('arc', { id: 'bird2', z: 6, t: { sx: 0.121, sy: 0.083, tx: 82.047, ty: 99.83 }, color: C.charcoal }),
  ];
}
const BASE = baseComposition();
const PEAK = MS.element('polyline', { id: 'peak', z: 7, t: PEAK_FINAL, color: C.plum });
const FINAL = [...BASE, PEAK];
// 갤러리에 미리 저장돼 있는 작품들 (같은 23종 도형으로 만든 예시)
const FLOWER = [
  MS.element('rose', { id: 'f1', z: 0, t: { sx: 1.012, sy: 1.012, tx: 0.42, ty: 2.181 }, color: '#E30B5D' }),
  MS.element('circle', { id: 'f2', z: 1, t: { sx: 0.251, sy: 0.251, tx: 0.42, ty: 2.181 }, color: '#FFC94A' }),
  MS.element('sine', { id: 'f3', z: 2, t: { sx: 1.493, sy: 0.224, rot: 90.6, tx: 0.817, ty: -123.95 }, color: '#046241' }),
  MS.element('ellipse', { id: 'f4', z: 3, t: { sx: 0.548, sy: 0.281, rot: 34.71, tx: 24.3, ty: -119.62 }, color: '#9ACD32' }),
  MS.element('ellipse', { id: 'f5', z: 4, t: { sx: 0.548, sy: 0.281, rot: -35.2, tx: -23.85, ty: -150.14 }, color: '#9ACD32' }),
  MS.element('cosine', { id: 'f6', z: 5, t: { sx: 3.012, sy: 0.149, tx: 0.5, ty: -205.3 }, color: '#8B5E34' }),
];
const MANDALA = [
  MS.element('epicycloid', { id: 'm1', z: 0, t: { sx: 0.9, sy: 0.9 }, color: '#C2185B' }),
  MS.element('hypocycloid', { id: 'm2', z: 1, t: { sx: 0.9, sy: 0.9, rot: 18 }, color: '#6B3FA0' }),
  MS.element('rose', { id: 'm3', z: 2, t: { sx: 0.55, sy: 0.55 }, color: '#FF6B35' }),
  MS.element('star', { id: 'm4', z: 3, t: { sx: 0.35, sy: 0.35 }, color: '#FFC94A' }),
];
const LINEDOT = [ // 실제 스크린샷의 "숯빛 검정" 작품과 같은 수식
  MS.element('point', { id: 'l1', z: 0 }),
  MS.element('line', { id: 'l2', z: 1, t: { rot: 104.162, ty: 0.879 } }),
];

// ───────────────────────── 장면 시간표 (초)
// 0 제목 카드 → 01 도형 → 02 조립·변형 → 03 수식 → 04 팔레트 서명·갤러리 → 장미 곡선이 아이콘이 되는 마무리(마지막 프레임 = 첫 프레임)
const T0 = 0.0, T1 = 1.5, T2 = 7.9, T3 = 18.9, T4 = 28.9, T5 = 35.7, DURATION = 41.2;

// ═════════════ 제목 카드 / 마무리: 장미 곡선(앱 아이콘의 모티프) → 아이콘 → 제목
const ICON_POS = { x: 478, y: 520, size: 300 };
const OPENER_END = 4.2; // 이 시점 이후 = 완성된 제목 카드
function opener(t) {
  t = Math.min(t, OPENER_END);
  ctx.save();
  const rose = MS.samplePoints('rose', { k: 5, r: 50 }, 720);
  const m = eIO(prog(t, 1.8, 2.6));                     // 큰 장미 → 아이콘 자리로
  const cx = lerp(960, ICON_POS.x, m), cy = lerp(450, ICON_POS.y, m);
  const petal = lerp(290, ICON_POS.size * 0.345, m);
  const k = petal / 50;
  const pts = rose.map(([x, y]) => [cx + x * k, cy - y * k]);
  // 아이콘 타일(그라디언트 라운드 사각형) — 장미가 내려앉으며 나타남
  const tileA = eOut(prog(t, 2.3, 2.7));
  if (tileA > 0) {
    const s = ICON_POS.size * lerp(0.86, 1, eOut(prog(t, 2.3, 2.8))), x = cx - s / 2, y = cy - s / 2;
    ctx.save(); ctx.globalAlpha *= tileA; shadow(50, 18, 0.22); rr(x, y, s, s, s * 0.2237); ctx.fillStyle = brandGrad(x, y, x + s, y + s); ctx.fill(); noShadow(); ctx.restore();
  }
  // 그려지는 장미 곡선 (그라디언트 선 → 흰 꽃잎)
  const dp = eIO(prog(t, 0.15, 1.75));
  const g = brandGrad(cx - petal, cy - petal, cx + petal, cy + petal);
  ctx.save(); ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  tracePartial(pts, true, dp);
  ctx.lineWidth = lerp(7, 5, m);
  if (tileA < 1) { ctx.save(); ctx.globalAlpha *= 1 - tileA; ctx.strokeStyle = g; ctx.stroke(); ctx.restore(); }
  if (tileA > 0) { ctx.save(); ctx.globalAlpha *= tileA; if (dp >= 1) { ctx.fillStyle = 'rgba(255,255,255,0.94)'; ctx.fill('nonzero'); } ctx.strokeStyle = '#FFFFFF'; ctx.stroke(); ctx.restore(); }
  ctx.restore();
  // 실제 앱 아이콘으로 교차 페이드
  const imgA = eOut(prog(t, 2.6, 3.0));
  if (imgA > 0 && IMG.icon) {
    const s = ICON_POS.size, x = ICON_POS.x - s / 2, y = ICON_POS.y - s / 2;
    ctx.save(); ctx.globalAlpha *= imgA; rr(x, y, s, s, s * 0.2237); ctx.clip(); ctx.drawImage(IMG.icon, x, y, s, s); ctx.restore();
  }
  // 장미 곡선 수식 (앱 포매터 그대로: rose(k: 5, r: 50))
  const fA = win(t, 0.5, 2.3, 0.4, 0.35);
  const formula = MS.formulaExpression('rose', { k: 5, r: 50 });
  if (fA > 0) {
    const chars = Array.from(formula); const n = Math.floor(chars.length * eOut(prog(t, 0.5, 1.7)));
    text(chars.slice(0, n).join(''), 960, 900, { size: 38, fam: F_MATH, color: INK, align: 'center', alpha: fA });
  }
  // 제목
  const tA = eOut(prog(t, 2.6, 3.3)), dx = (1 - tA) * 40;
  if (tA > 0) {
    const x = 698 + dx;
    text('MathSketch', x, 470, { size: 112, weight: 700, fam: F_EN, alpha: tA, ls: -2 });
    text('수식으로 그림을 그리고, 그림을 다시 하나의 완전한 수식으로', x + 4, 552, { size: 38, weight: 500, alpha: eOut(prog(t, 2.85, 3.5)) });
    text('점·선·면부터 극좌표 곡선까지 — 23종의 기하 요소를 조립하는 iOS · iPadOS 앱', x + 4, 612, { size: 27, color: GRAY, alpha: eOut(prog(t, 3.05, 3.7)) });
    text(MS.formulaExpression('rose', { k: 5, r: 50 }), x + 4, 690, { size: 26, fam: F_MATH, color: GRAY2, alpha: eOut(prog(t, 3.25, 3.9)) * 0.9 });
  }
  ctx.restore();
}

function sceneTitle(t) { // 첫 프레임부터 완성된 제목 카드 → 페이드아웃
  const a = win(t, T0, T1, 0, 0.4);
  if (a <= 0) return;
  opener(OPENER_END); fadeOverlay(a);
}
function sceneOutro(t) { // 흰 화면에서 장미 곡선이 그려지고 아이콘·제목이 된다 — 끝 프레임이 sceneTitle 과 같다
  if (t < T5) return;
  opener(t - T5);
}

// ═════════════ S1 — 01 23종의 수식 도형
const CAT_COLOR = { basics: CHARCOAL, lines: '#1E3A8A', closedShapes: '#C2185B', trig: '#0E7C7B', polar: '#6B3FA0' };
const GRID = { x0: 380, y0: 232, cw: 196, ch: 124, gx: 14, gy: 12 };
function gridCells() {
  const cells = []; let k = 0;
  MS.byCategory.forEach((g, row) => g.kinds.forEach((kind, col) => {
    cells.push({ kind, row, col, k: k++, cat: g.category, x: GRID.x0 + col * (GRID.cw + GRID.gx), y: GRID.y0 + row * (GRID.ch + GRID.gy) });
  }));
  return cells;
}
const CELLS = gridCells();
function specimen(c, o) {
  const { alpha = 1, progress = 1, hi = 0, dim = 0 } = o;
  if (alpha <= 0) return;
  ctx.save(); ctx.globalAlpha *= alpha * (1 - 0.6 * dim);
  const sc = 1 + 0.06 * hi, cxm = c.x + GRID.cw / 2, cym = c.y + GRID.ch / 2;
  ctx.translate(cxm, cym); ctx.scale(sc, sc); ctx.translate(-cxm, -cym);
  if (hi > 0) { shadow(30 * hi, 10 * hi, 0.14 * hi); }
  rr(c.x, c.y, GRID.cw, GRID.ch, 18); ctx.fillStyle = hi > 0 ? mix('#F3F3F6', '#FFFFFF', hi) : '#F3F3F6'; ctx.fill(); noShadow();
  if (hi > 0) { ctx.save(); ctx.globalAlpha *= hi; ctx.lineWidth = 3; ctx.strokeStyle = brandGrad(c.x, c.y, c.x + GRID.cw, c.y + GRID.ch); rr(c.x, c.y, GRID.cw, GRID.ch, 18); ctx.stroke(); ctx.restore(); }
  const rect = { x: c.x + 30, y: c.y + 12, w: GRID.cw - 60, h: 70 };
  ctx.save(); ctx.beginPath(); ctx.rect(c.x + 8, c.y + 6, GRID.cw - 16, 84); ctx.clip();
  for (const it of MS.fit([MS.element(c.kind, { color: CAT_COLOR[c.cat] })], rect)) drawItem(it, { lw: 3, pointR: 8, progress });
  ctx.restore();
  text(MS.DISPLAY_NAME[c.kind], c.x + GRID.cw / 2, c.y + GRID.ch - 14, { size: 22, weight: 500, align: 'center', alpha: eOut(clamp(progress * 1.6, 0, 1)) });
  ctx.restore();
}
function scene1(t) {
  const a = win(t, T1, T2, 0.35, 0.4);
  if (a <= 0) return;
  const tau = t - T1;
  ctx.save();
  header('01', '23종의 수식 도형', '점·선·면에서 극좌표 곡선까지', eOut(prog(tau, 0, 0.5)));
  // 카테고리 이름
  MS.byCategory.forEach((g, row) => {
    const y = GRID.y0 + row * (GRID.ch + GRID.gy) + GRID.ch / 2 + 9;
    text(g.name, 120, y, { size: 26, weight: 600, color: CAT_COLOR[g.category], alpha: eOut(prog(tau, 0.25 + row * 0.12, 0.65 + row * 0.12)) });
    text(String(g.kinds.length) + '종', 120, y + 34, { size: 20, color: GRAY2, fam: F_EN, alpha: eOut(prog(tau, 0.35 + row * 0.12, 0.75 + row * 0.12)) });
  });
  // 스포트라이트: 장미 곡선 → 별다각형(바닥함수까지 생략 없는 수식)
  const spots = [['rose', 3.25, 4.75], ['star', 4.75, 6.4]];
  let hiKind = null, hiAmt = 0;
  for (const [kind, s, e] of spots) { const v = win(tau, s, e, 0.3, 0.3); if (v > hiAmt) { hiAmt = v; hiKind = kind; } }
  const anyHi = Math.max(...spots.map(([, s, e]) => win(tau, s, e, 0.3, 0.3)));
  for (const c of CELLS) {
    const st = 0.45 + c.k * 0.085;
    const p = eIO(prog(tau, st, st + 0.75));
    const cellA = eOut(prog(tau, st - 0.15, st + 0.2));
    const hi = c.kind === hiKind ? hiAmt : 0;
    specimen(c, { alpha: cellA, progress: p, hi, dim: c.kind === hiKind ? 0 : anyHi });
  }
  // 하단: 설명 → 스포트라이트 수식
  caption('모든 도형은 자기만의 매개변수 방정식을 가진다 — 팔레트에서 탭하면 중앙에, 끌어다 놓으면 그 자리에', win(tau, 0.6, 3.3, 0.4, 0.3), 1012);
  for (const [kind, s, e] of spots) {
    const v = win(tau, s, e, 0.3, 0.3); if (v <= 0) continue;
    const name = MS.DISPLAY_NAME[kind];
    text(name, 120, 1000, { size: 30, weight: 700, alpha: v });
    const nx = 120 + measure(name, 30, 700) + 26;
    const lines = wrapLines(MS.formulaExpression(kind, {}), 1800 - nx, 30, 400, F_MATH);
    const y0 = lines.length > 1 ? 982 : 1000;
    lines.forEach((l, i) => text(l, nx, y0 + i * 42, { size: 30, fam: F_MATH, alpha: v }));
  }
  ctx.restore();
  fadeOverlay(a);
}

// ═════════════ S2 — 02 조립하고, 변형한다
const STRIP = { x: 120, y: 236, S: 1.42 };
const CANVAS2 = { x: 120, y: 410, w: 1030, h: 548 };
const INSP = { x: 1196, y: 410, w: 604, S: 1.42 };
function stripChips() {
  const S = STRIP.S, out = []; let x = STRIP.x;
  for (const g of MS.byCategory) {
    out.push({ label: g.name, x, cat: true });
    for (const kind of g.kinds) { out.push({ kind, x, y: STRIP.y + 22 * S }); x += 76 * S + 8 * S; }
    x += 18 * S - 8 * S;
  }
  return out;
}
const STRIP_ITEMS = stripChips();
const POLY_CHIP = STRIP_ITEMS.find(i => i.kind === 'polyline');
// 산봉우리(꺾은선)를 실시간으로 조립하는 상태 — tau: S2 시작부터의 시간
function peakAt(tau) {
  if (tau < 1.9) return null;
  const rot = 179.4 * eIO(prog(tau, 2.15, 3.35));
  const s = lerp(1, PEAK_FINAL.sx, eIO(prog(tau, 3.55, 4.45)));
  const sy = tau < 4.65 ? s : lerp(PEAK_FINAL.sx, PEAK_FINAL.sy, eIO(prog(tau, 4.65, 5.35)));
  const shx = lerp(0, PEAK_FINAL.shx, eIO(prog(tau, 5.6, 6.8)));
  const mv = eIO(prog(tau, 7.05, 8.05));
  const tx = lerp(PEAK_DROP[0], PEAK_FINAL.tx, mv), ty = lerp(PEAK_DROP[1], PEAK_FINAL.ty, mv);
  const c = prog(tau, 8.45, 8.75);
  const t = { sx: s, sy, rot, shx, shy: 0, tx, ty };
  if (mv >= 1) { t.tx = PEAK_FINAL.tx; t.ty = PEAK_FINAL.ty; }
  return MS.element('polyline', { id: 'peak', z: 7, t, color: c >= 1 ? C.plum : mix(CHARCOAL, C.plum, c) });
}
function scene2(t) {
  const a = win(t, T2, T3, 0.35, 0.4);
  if (a <= 0) return;
  const tau = t - T2;
  ctx.save();
  header('02', '조립하고, 변형한다', '드래그 · 핀치 · 회전 · 비틀기', eOut(prog(tau, 0, 0.5)));
  const S = STRIP.S;
  // 팔레트 줄
  const stripA = eOut(prog(tau, 0.15, 0.6));
  ctx.save(); ctx.globalAlpha *= stripA; ctx.beginPath(); ctx.rect(100, STRIP.y - 10, 1720, 160); ctx.clip();
  for (const it of STRIP_ITEMS) {
    if (it.cat) { text(it.label, it.x + 2, STRIP.y + 10 * S, { size: 11 * S * 1.15, color: GRAY }); continue; }
    const press = it.kind === 'polyline' ? win(tau, 0.95, 1.25, 0.08, 0.15) : 0;
    chip(it.kind, it.x, it.y, S, { scale: 1 - 0.05 * press, ring: press });
  }
  ctx.restore();
  // 오른쪽 가장자리 페이드(가로 스크롤 팔레트 느낌)
  const fadeG = ctx.createLinearGradient(1700, 0, 1820, 0); fadeG.addColorStop(0, 'rgba(255,255,255,0)'); fadeG.addColorStop(1, 'rgba(255,255,255,1)');
  ctx.fillStyle = fadeG; ctx.fillRect(1700, STRIP.y - 10, 120, 160);

  // 캔버스
  const peak = peakAt(tau);
  const elements = peak ? [...BASE, peak] : BASE;
  const selected = tau >= 1.9 && tau < 9.25 ? 'peak' : null;
  const canA = eOut(prog(tau, 0.2, 0.7));
  const fitted = canvasCard(CANVAS2, elements, {
    S: 2.0, lw: 4, alpha: canA, selectedId: selected,
    progressOf: el => (el.id === 'peak' ? 1 : eIO(prog(tau, 0.35 + el.z * 0.08, 1.05 + el.z * 0.08))),
  });
  const fctx = MS.fitContext(elements, CANVAS2);
  // 제스처 배지
  const badges = [[0.9, 2.0, '팔레트에서 끌어다 놓기'], [2.0, 3.45, '두 손가락 회전'], [3.45, 4.55, '핀치 — 배율'], [4.55, 5.45, '슬라이더 — 스케일 Y'], [5.45, 6.9, '슬라이더 — 비틀기 X'], [6.9, 8.15, '드래그 — 이동'], [8.15, 9.0, '색상 — 장식 전용']];
  for (const [s, e, label] of badges) pill(CANVAS2.x + 24, CANVAS2.y + 22, label, { alpha: win(tau, s, e, 0.2, 0.2), size: 24, color: INK });

  // 인스펙터
  let ins = null;
  if (peak) {
    const insA = eOut(prog(tau, 1.95, 2.3)) * (1 - eIn(prog(tau, 9.2, 9.5)));
    const slide = (1 - eOut(prog(tau, 1.95, 2.35))) * 50 + eIn(prog(tau, 9.2, 9.5)) * 50;
    ins = inspector(INSP.x + slide, INSP.y, INSP.w, INSP.S, {
      name: MS.DISPLAY_NAME.polyline, label: MS.label(peak), vals: peak.t, color: peak.color,
      token: tau < 2.15 ? 'translate' : tau < 3.45 ? 'rotate' : tau < 4.55 ? 'scale' : tau < 5.45 ? 'scale' : tau < 6.9 ? 'shear' : tau < 8.15 ? 'translate' : null,
      active: { sy: win(tau, 4.55, 5.45, 0.1, 0.1), shx: win(tau, 5.45, 6.9, 0.1, 0.1), rot: win(tau, 2.1, 3.4, 0.15, 0.15) * 0.0, color: win(tau, 8.2, 8.9, 0.1, 0.2) },
    }, insA);
  } else {
    // 선택 전: 안내
    const ga = canA * (1 - prog(tau, 1.6, 1.9));
    ctx.save(); ctx.globalAlpha *= ga; ctx.setLineDash([8, 7]); ctx.lineWidth = 2; ctx.strokeStyle = LIGHT; rr(INSP.x, INSP.y, INSP.w, 548, 20); ctx.stroke(); ctx.restore();
    text('인스펙터', INSP.x + INSP.w / 2, INSP.y + 250, { size: 30, weight: 600, color: GRAY2, align: 'center', alpha: ga });
    text('요소를 놓거나 탭하면 여기에 열린다', INSP.x + INSP.w / 2, INSP.y + 296, { size: 24, color: GRAY2, align: 'center', alpha: ga });
  }

  // 손가락 · 고스트 칩
  const chipW = 76 * S, chipH = 84 * S;
  const chipC = [POLY_CHIP.x + chipW / 2, POLY_CHIP.y + chipH / 2];
  const dropV = fctx.toView(PEAK_DROP);
  if (tau >= 0.85 && tau < 2.0) {
    const mvp = eIO(prog(tau, 1.15, 1.8));
    const fx = lerp(chipC[0], dropV[0], mvp), fy = lerp(chipC[1], dropV[1], mvp);
    if (tau > 1.12 && tau < 1.9) { ctx.save(); ctx.globalAlpha *= 0.85 * (1 - prog(tau, 1.75, 1.9)); chip('polyline', fx - chipW / 2, fy - chipH / 2, S, { lift: 1, bg: '#FFFFFF', scale: 1.04 }); ctx.restore(); }
    finger(fx, fy, win(tau, 0.85, 2.0, 0.1, 0.15), tau > 0.98 && tau < 1.85 ? 1 : 0);
  }
  const peakIt = fitted && fitted.find(f => f.el.id === 'peak');
  if (peakIt) {
    const b = MS.bbox(peakIt.pts), pc = [b.x + b.w / 2, b.y + b.h / 2];
    // 회전: 두 손가락이 중심을 축으로 반시계로 돈다
    const ra = win(tau, 2.0, 3.5, 0.12, 0.15);
    if (ra > 0) { const ang = Math.PI * 0.2 + (peak.t.rot * Math.PI) / 180; const R = 120; finger(pc[0] + R * Math.cos(ang), pc[1] - R * Math.sin(ang), ra, 1); finger(pc[0] - R * Math.cos(ang), pc[1] + R * Math.sin(ang), ra, 1); }
    // 핀치: 대각선으로 벌어진다
    const pa = win(tau, 3.4, 4.6, 0.12, 0.15);
    if (pa > 0) { const d = 70 * peak.t.sx; finger(pc[0] - d, pc[1] + d * 0.55, pa, 1); finger(pc[0] + d, pc[1] - d * 0.55, pa, 1); }
    // 이동 드래그
    const da = win(tau, 6.9, 8.2, 0.12, 0.15);
    if (da > 0) finger(pc[0], pc[1] + 6, da, tau > 7.0 && tau < 8.1 ? 1 : 0);
  }
  if (ins) {
    const sa = win(tau, 4.5, 5.45, 0.12, 0.15); if (sa > 0) finger(ins.thumbs.sy[0], ins.thumbs.sy[1], sa, 1);
    const sh = win(tau, 5.45, 6.95, 0.12, 0.15); if (sh > 0) finger(ins.thumbs.shx[0], ins.thumbs.shx[1], sh, 1);
    const ca = win(tau, 8.2, 8.8, 0.08, 0.15); if (ca > 0) finger(ins.colorPos[0], ins.colorPos[1], ca, tau > 8.3 && tau < 8.6 ? 1 : 0);
    const xa = win(tau, 8.95, 9.4, 0.08, 0.12); if (xa > 0) finger(ins.xmarkPos[0], ins.xmarkPos[1], xa, tau > 9.08 && tau < 9.25 ? 1 : 0);
  }
  captions(tau, [
    [0.4, 2.05, '팔레트에서 탭하면 캔버스 중앙에, 끌어다 놓으면 놓은 자리에 추가된다'],
    [2.05, 4.55, '두 손가락으로 회전·핀치 — 제스처가 진행되는 동안 수식 라벨이 매 프레임 갱신된다'],
    [4.55, 6.95, '인스펙터 슬라이더로 비균일 스케일과 비틀기(전단)까지'],
    [6.95, 9.3, '드래그로 이동 · 색은 장식 전용이라 수식에는 들어가지 않는다'],
    [9.3, 11.0, '모든 조작은 제스처 단위로 실행 취소 · 다시 실행할 수 있다'],
  ]);
  ctx.restore();
  fadeOverlay(a);
}

// ═════════════ S3 — 03 그림 전체가 하나의 수식으로
const PANEL3 = { x: 120, y: 236, w: 1110, h: 728 };
const CARD3 = { x: 1290, y: 236, w: 510, h: 322 };
const CARD3B = { x: 1290, y: 616, w: 510, h: 322 };
function narrativeLayout(nar, maxW, size) {
  const rows = [];
  rows.push({ text: nar.header, line: -1, fam: F_MATH });
  nar.lines.forEach((l, i) => {
    const full = (l.annotation ? `${l.label}${l.equation}   —  ${l.annotation}` : `${l.label}${l.equation}`);
    wrapLines(full, maxW, size, 400, F_MATH).forEach((w, j) => rows.push({ text: w, line: i, first: j === 0 }));
  });
  return rows;
}
let NAR_CACHE = null;
function narrativeRows() {
  if (NAR_CACHE) return NAR_CACHE;
  const nar = MS.narrative(FINAL);
  const maxW = PANEL3.w - 64;
  for (let size = 32; size >= 18; size -= 0.5) {
    const rows = narrativeLayout(nar, maxW, size);
    const h = rows.length * size * 1.5 + 8 * size * 0.35;
    if (h <= PANEL3.h - 150) { NAR_CACHE = { rows, size, nar }; return NAR_CACHE; }
  }
  NAR_CACHE = { rows: narrativeLayout(nar, maxW, 18), size: 18, nar }; return NAR_CACHE;
}
function scene3(t) {
  const a = win(t, T3, T4, 0.35, 0.4);
  if (a <= 0) return;
  const tau = t - T3;
  ctx.save();
  header('03', '그림 전체가 하나의 수식으로', '생략 없이, 그대로 다시 그릴 수 있게', eOut(prog(tau, 0, 0.5)));
  captions(tau, [
    [0.4, 4.6, '캔버스의 모든 요소가 𝑃₁(𝑡) … 𝑃₈(𝑡)로 — 꺾은선·하이포사이클로이드까지 요약 없는 닫힌형 방정식 그대로'],
    [4.6, 7.25, '원본 수식(SketchFormula)은 복사·붙여넣기용 — 도형과 변형만 담고 색은 담지 않는다'],
    [7.25, 8.8, '문자열을 파싱하는 즉시 같은 위치·크기·회전으로 재구성된다'],
    [8.8, 10.0, '제스처 단위로 쌓인 실행 취소 스택 — 한 번에 직전 상태로'],
  ]);
  const { rows, size } = narrativeRows();
  const N = FINAL.length;
  const lineStart = i => 0.85 + i * 0.42;
  const curLine = (() => { for (let i = N - 1; i >= 0; i--) if (tau >= lineStart(i)) return tau < lineStart(N - 1) + 0.42 ? i : -2; return -1; })();
  const hiA = 1 - prog(tau, lineStart(N - 1) + 0.42, lineStart(N - 1) + 0.8);
  // 수식 패널 (FormulaBarView: "수식" + 복사/수식으로 그리기 버튼 + 세리프 서술형 수식)
  const P = PANEL3, panA = eOut(prog(tau, 0.15, 0.6));
  ctx.save(); ctx.globalAlpha *= panA;
  rr(P.x, P.y, P.w, P.h, 22); ctx.fillStyle = '#F4F4F7'; ctx.fill();
  text('수식', P.x + 32, P.y + 50, { size: 22, color: GRAY });
  const copyPress = win(tau, 5.15, 5.45, 0.05, 0.12), fxPress = win(tau, 5.75, 6.05, 0.05, 0.12);
  ICON.copy(P.x + P.w - 108, P.y + 42, 34);
  ICON.fx(P.x + P.w - 50, P.y + 42, 34);
  // 내용: 서술형 수식 → (스크롤) → 원본 수식(DSL)
  const narOut = 1 - eIO(prog(tau, 4.4, 4.8));
  ctx.save(); rr(P.x, P.y + 70, P.w, P.h - 70, 0); ctx.clip();
  const lh = size * 1.5;
  let y = P.y + 70 + size + 8;
  ctx.save(); ctx.globalAlpha *= narOut;
  for (const r of rows) {
    if (r.line >= 0 && r.first) y += size * 0.35;
    const vis = r.line < 0 ? eOut(prog(tau, 0.55, 0.85)) : eOut(prog(tau, lineStart(r.line), lineStart(r.line) + 0.3));
    if (vis > 0) {
      const isCur = r.line === curLine && hiA > 0;
      if (isCur) { ctx.save(); ctx.globalAlpha *= hiA * 0.9; rr(P.x + 18, y - size * 1.05, P.w - 36, lh, 8); ctx.fillStyle = '#E6E3F3'; ctx.fill(); ctx.restore(); }
      const dim = curLine >= 0 && !isCur && r.line >= 0 ? 0.45 * hiA : 0;
      text(r.text, P.x + 32 + (1 - vis) * 16, y, { size, fam: F_MATH, color: INK, alpha: vis * (1 - dim) });
    }
    y += lh;
  }
  ctx.restore();
  // 원본 수식 (복사·붙여넣기용) — DisclosureGroup: 서술형 수식이 물러나고 펼쳐진다
  const dslTitleY = lerp(Math.min(y + 26, P.y + P.h - 30), P.y + 122, eIO(prog(tau, 4.45, 4.9)));
  const dtA = eOut(prog(tau, 4.2, 4.6));
  text('원본 수식 (복사·붙여넣기용)', P.x + 32, dslTitleY, { size: 22, color: BLUE, alpha: dtA });
  if (dtA > 0) { ctx.save(); ctx.globalAlpha *= dtA; ICON.chevronDown(P.x + 32 + measure('원본 수식 (복사·붙여넣기용)', 22) + 22, dslTitleY - 7, 20, BLUE); ctx.restore(); }
  const dsl = MS.dsl(FINAL);
  const dslLines = wrapLines(dsl, P.w - 64, 21, 400, F_MONO);
  const dslA = eOut(prog(tau, 4.75, 5.15));
  dslLines.forEach((l, i) => text(l, P.x + 32, dslTitleY + 50 + i * 34, { size: 21, fam: F_MONO, color: '#3A3A3C', alpha: dslA }));
  ctx.restore();
  // 버튼 눌림 표시
  if (copyPress > 0) { ctx.save(); ctx.globalAlpha *= copyPress * 0.25; ctx.fillStyle = BLUE; ctx.beginPath(); ctx.arc(P.x + P.w - 108, P.y + 42, 30, 0, TAU); ctx.fill(); ctx.restore(); }
  if (fxPress > 0) { ctx.save(); ctx.globalAlpha *= fxPress * 0.25; ctx.fillStyle = BLUE; ctx.beginPath(); ctx.arc(P.x + P.w - 50, P.y + 42, 30, 0, TAU); ctx.fill(); ctx.restore(); }
  ctx.restore();

  // 오른쪽: 원본 캔버스 (현재 줄의 요소를 강조)
  const hiId = curLine >= 0 ? FINAL[curLine].id : null;
  canvasCard(CARD3, FINAL, {
    S: 1, lw: 3, alpha: eOut(prog(tau, 0.2, 0.65)), shadow: false,
    alphaOf: el => (hiId && el.id !== hiId ? 1 - 0.8 * hiA : 1),
    colorOf: el => el.color,
  });
  text('원본 캔버스 — 색 포함', CARD3.x + 4, CARD3.y + CARD3.h + 36, { size: 22, color: GRAY, alpha: eOut(prog(tau, 0.3, 0.7)) });
  if (hiId && hiA > 0) {
    const it = MS.fit(FINAL, CARD3).find(f => f.el.id === hiId);
    if (it) { const b = MS.bbox(it.pts); ctx.save(); ctx.globalAlpha *= hiA; ctx.setLineDash([6, 5]); ctx.strokeStyle = BLUE; ctx.lineWidth = 2; ctx.strokeRect(b.x - 10, b.y - 10, Math.max(b.w, 1) + 20, Math.max(b.h, 1) + 20); ctx.restore();
      text(`𝑃${MS.subscript(curLine + 1)}`, b.x + b.w + 14, b.y - 4, { size: 26, fam: F_MATH, color: BLUE, alpha: hiA }); }
  }
  // "수식으로 그리기" 시트 — 현재 수식이 채워진 채로 열림 → 그리기
  const sheetIn = eOut(prog(tau, 6.05, 6.55)), sheetOut = eIn(prog(tau, 7.15, 7.4));
  const sheetY = lerp(H + 20, 300, sheetIn) + sheetOut * 40;
  if (sheetIn > 0 && sheetOut < 1) {
    const sx = 150, sw = 1050, sh = 640;
    ctx.save(); ctx.globalAlpha *= 1 - sheetOut; shadow(60, -6, 0.18); rr(sx, sheetY, sw, sh, 34); ctx.fillStyle = '#F2F2F7'; ctx.fill(); noShadow();
    text('취소', sx + 40, sheetY + 62, { size: 26, color: INK });
    text('수식으로 그리기', sx + sw / 2, sheetY + 62, { size: 28, weight: 700, align: 'center' });
    const drawPress = win(tau, 6.85, 7.15, 0.05, 0.1);
    rr(sx + sw - 150, sheetY + 28, 112, 50, 25); ctx.fillStyle = mix('#007AFF', '#0051C7', drawPress); ctx.fill();
    text('그리기', sx + sw - 94, sheetY + 62, { size: 25, weight: 700, color: '#fff', align: 'center' });
    text('SketchFormula (도형 + 변형, 색상 없음)', sx + 44, sheetY + 130, { size: 22, color: GRAY });
    rr(sx + 30, sheetY + 148, sw - 60, sh - 180, 18); ctx.fillStyle = '#fff'; ctx.fill();
    wrapLines(dsl, sw - 110, 20, 400, F_MONO).forEach((l, i) => text(l, sx + 56, sheetY + 194 + i * 31, { size: 20, fam: F_MONO, color: INK }));
    ctx.restore();
    finger(sx + sw - 94, sheetY + 53, win(tau, 6.7, 7.25, 0.1, 0.12), tau > 6.85 && tau < 7.12 ? 1 : 0);
  }
  // 손가락: 복사 → f(x)
  finger(P.x + P.w - 108, P.y + 42, win(tau, 5.0, 5.5, 0.1, 0.1), tau > 5.15 && tau < 5.4 ? 1 : 0);
  finger(P.x + P.w - 50, P.y + 42, win(tau, 5.6, 6.1, 0.1, 0.1), tau > 5.75 && tau < 6.0 ? 1 : 0);

  // 오른쪽 아래: 수식 문자열만으로 다시 그린 캔버스 (색은 기본 중립색 #1C1C1E)
  const rebuilt = FINAL.map(e => MS.element(e.kind, { id: e.id + '_r', z: e.z, params: e.params, t: e.t }));
  const rbA = eOut(prog(tau, 7.25, 7.45));
  const undoT = 8.95;
  const back = eIO(prog(tau, undoT + 0.1, undoT + 0.45));
  canvasCard(CARD3B, rebuilt, {
    S: 1, lw: 3, alpha: rbA,
    colorOf: el => mix(CHARCOAL, FINAL.find(f => f.id + '_r' === el.id).color, back),
  });
  text(back < 0.5 ? '수식 문자열만으로 다시 그림 — 형태 동일, 색은 기본 중립색' : '실행 취소 한 번 — 직전 상태(색 포함)로', CARD3B.x + 4, CARD3B.y + CARD3B.h + 36, { size: 22, color: GRAY, alpha: rbA });
  // 실행 취소 버튼 (툴바의 ↶ ↷ 캡슐)
  const ub = win(tau, 8.4, 10.0, 0.3, 0.3);
  if (ub > 0) {
    const bx = CARD3B.x + 16, by = CARD3B.y + 16;
    ctx.save(); ctx.globalAlpha *= ub; shadow(16, 4, 0.12); rr(bx, by, 134, 54, 27); ctx.fillStyle = '#fff'; ctx.fill(); noShadow();
    ICON.undo(bx + 40, by + 27, 30, INK); ICON.redo(bx + 94, by + 27, 30, back > 0.5 ? INK : LIGHT); ctx.restore();
    finger(bx + 40, by + 27, win(tau, undoT - 0.2, undoT + 0.35, 0.1, 0.12), tau > undoT - 0.05 && tau < undoT + 0.15 ? 1 : 0);
  }
  ctx.restore();
  fadeOverlay(a);
}

// ═════════════ S4 — 04 팔레트 서명 · 갤러리
const PHONE = { cx: 1520, cy: 560, h: 900 };
function phoneFrame(cx, cy, h, alpha, drawScreen) {
  if (alpha <= 0) return;
  const bz = 12, sw = 393, sh = 852, bw = sw + bz * 2, bh = sh + bz * 2, k = h / bh;
  ctx.save();
  ctx.translate(cx - (bw * k) / 2, cy - (bh * k) / 2); ctx.scale(k, k);
  shadow(60, 24, 0.20); rr(0, 0, bw, bh, 66); ctx.fillStyle = '#1C1C1E'; ctx.fill(); noShadow();
  ctx.lineWidth = 2; ctx.strokeStyle = '#48484A'; rr(1, 1, bw - 2, bh - 2, 65); ctx.stroke();
  ctx.save(); ctx.translate(bz, bz); rr(0, 0, sw, sh, 55); ctx.clip(); ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, sw, sh);
  drawScreen(sw, sh);
  // 상태 막대 + 다이내믹 아일랜드 (아래에서 그림)
  text('9:41', 64, 38, { size: 17, weight: 600, fam: F_EN, align: 'center' });
  rr(133, 11, 126, 37, 18.5); ctx.fillStyle = '#000'; ctx.fill();
  ctx.fillStyle = INK; [0, 1, 2, 3].forEach(i => { rr(300 + i * 6, 34 - (4 + i * 2.6), 4, 4 + i * 2.6, 1); ctx.fill(); });
  rr(336, 24, 25, 12, 3.5); ctx.lineWidth = 1.2; ctx.strokeStyle = INK; ctx.stroke(); rr(338, 26, 19, 8, 2); ctx.fill();
  ctx.restore(); ctx.restore();
  fadeOverlay(alpha, { x: cx - (bw * k) / 2 - 80, y: cy - (bh * k) / 2 - 60, w: bw * k + 160, h: bh * k + 140 });
}
function thumb(elements, x, y, s, r = 10) {
  rr(x, y, s, s, r); ctx.fillStyle = '#fff'; ctx.fill(); ctx.lineWidth = 0.6; ctx.strokeStyle = '#E5E5EA'; ctx.stroke();
  ctx.save(); rr(x, y, s, s, r); ctx.clip();
  for (const it of MS.fit(elements, { x, y, w: s, h: s })) drawItem(it, { lw: Math.max(1, 2 * s / 300), pointR: 6 * s / 300 });
  ctx.restore();
}
function tabBar(sw, sh, sel) {
  const w = 190, h = 62, x = (sw - w) / 2, y = sh - 96;
  ctx.save(); shadow(20, 6, 0.12); rr(x, y, w, h, 31); ctx.fillStyle = 'rgba(255,255,255,0.96)'; ctx.fill(); noShadow();
  ctx.lineWidth = 0.8; ctx.strokeStyle = '#E5E5EA'; ctx.stroke();
  const items = [['캔버스', ICON.canvasTab], ['갤러리', ICON.galleryTab]];
  items.forEach(([label, ic], i) => {
    const ix = x + 6 + i * 89, on = i === sel;
    if (on) { rr(ix, y + 5, 89, 52, 26); ctx.fillStyle = '#EDEDF0'; ctx.fill(); }
    ic(ix + 44.5, y + 24, 24, on ? BLUE : INK);
    text(label, ix + 44.5, y + 50, { size: 10, weight: 600, align: 'center', color: on ? BLUE : INK });
  });
  ctx.restore();
}
const SAVE_TITLE = MS.caption(FINAL);
function galleryScreen(sw, sh, tau) {
  text('갤러리', 16, 152, { size: 34, weight: 700 });
  const pop = eBack(prog(tau, 3.75, 4.15));
  const works = [[FINAL, SAVE_TITLE, pop], [FLOWER, MS.caption(FLOWER), 1], [MANDALA, MS.caption(MANDALA), 1], [LINEDOT, MS.caption(LINEDOT), 1]];
  const cw = (sw - 32 - 12) / 2;
  const shift = eIO(prog(tau, 3.6, 3.95));
  works.forEach(([els, title, sc], i) => {
    if (i === 0 && sc <= 0) return;
    // 새 작품이 맨 앞에 들어오며 나머지가 한 칸씩 밀린다 (createdAt 내림차순)
    const ix = i === 0 ? 16 : lerp(16 + ((i - 1) % 2) * (cw + 12), 16 + (i % 2) * (cw + 12), shift);
    const iy = i === 0 ? 176 : lerp(176 + Math.floor((i - 1) / 2) * (cw + 40), 176 + Math.floor(i / 2) * (cw + 40), shift);
    ctx.save(); if (i === 0) { ctx.translate(ix + cw / 2, iy + cw / 2); ctx.scale(sc, sc); ctx.translate(-(ix + cw / 2), -(iy + cw / 2)); }
    thumb(els, ix, iy, cw, 10);
    let tt = title; while (measure(tt, 12, 400) > cw && tt.length > 2) tt = tt.slice(0, -2) + '…';
    text(tt, ix, iy + cw + 18, { size: 12 });
    ctx.restore();
  });
  tabBar(sw, sh, 1);
}
function detailSheet(sw, sh, tau, inA) {
  // 배경 디밍
  ctx.save(); ctx.fillStyle = `rgba(0,0,0,${0.22 * inA})`; ctx.fillRect(0, 0, sw, sh); ctx.restore();
  const y0 = lerp(sh + 10, 58, eOut(inA));
  ctx.save(); ctx.translate(0, y0);
  rr(0, 0, sw, sh, 38); ctx.fillStyle = '#fff'; ctx.fill();
  // 툴바
  ctx.save(); shadow(10, 2, 0.08);
  rr(16, 14, 62, 44, 22); ctx.fillStyle = '#fff'; ctx.fill(); rr(214, 14, 163, 44, 22); ctx.fill(); noShadow(); ctx.restore();
  ctx.lineWidth = 0.6; ctx.strokeStyle = '#E5E5EA'; rr(16, 14, 62, 44, 22); ctx.stroke(); rr(214, 14, 163, 44, 22); ctx.stroke();
  text('닫기', 47, 42, { size: 15, align: 'center' });
  ICON.trash(240, 36, 22, INK);
  const openPress = win(tau, 5.95, 6.3, 0.05, 0.12);
  if (openPress > 0) { ctx.save(); ctx.globalAlpha *= openPress; rr(262, 18, 110, 36, 18); ctx.fillStyle = '#E5F0FF'; ctx.fill(); ctx.restore(); }
  text('캔버스로 열기', 318, 42, { size: 15, weight: 700, align: 'center', color: openPress > 0 ? BLUE : INK });
  // 스크롤되는 내용
  const sc = eIO(prog(tau, 5.2, 5.9)) * 150;
  ctx.save(); ctx.beginPath(); ctx.rect(0, 64, sw, sh); ctx.clip(); ctx.translate(0, -sc);
  let tt = SAVE_TITLE; while (measure(tt, 30, 700) > sw - 32 && tt.length > 2) tt = tt.slice(0, -2) + '…';
  text(tt, 16, 112, { size: 30, weight: 700 });
  thumb(FINAL, 16, 132, sw - 32, 14);
  text(`합성 수식 (${FINAL.length}개 요소)`, 16, 132 + sw - 32 + 30, { size: 12, color: GRAY });
  const dl = wrapLines(MS.dsl(FINAL), sw - 32, 12.5, 400, F_MONO);
  dl.forEach((l, i) => text(l, 16, 132 + sw - 32 + 52 + i * 17, { size: 12.5, fam: F_MONO }));
  const py = 132 + sw - 32 + 52 + dl.length * 17 + 18;
  text('팔레트 서명', 16, py, { size: 12, color: GRAY });
  MS.swatches(FINAL).forEach((s, i) => { ctx.beginPath(); ctx.arc(27 + i * 30, py + 24, 11, 0, TAU); ctx.fillStyle = s.hex; ctx.fill(); });
  ctx.restore();
  ctx.restore();
}
function scene4(t) {
  const a = win(t, T4, T5, 0.35, 0.4);
  if (a <= 0) return;
  const tau = t - T4;
  ctx.save();
  header('04', '색은 이름으로, 작품은 갤러리로', null, eOut(prog(tau, 0, 0.5)));
  // 팔레트 서명 패널 (PaletteSignatureView 확대) — 스와치 + 한 줄 캡션
  const P = { x: 120, y: 236, w: 1010, h: 330 };
  const panA = eOut(prog(tau, 0.15, 0.55));
  ctx.save(); ctx.globalAlpha *= panA; rr(P.x, P.y, P.w, P.h, 22); ctx.fillStyle = '#F4F4F7'; ctx.fill(); ctx.restore();
  text('팔레트 서명', P.x + 32, P.y + 50, { size: 22, color: GRAY, alpha: panA });
  const sw = MS.swatches(FINAL);
  sw.forEach((s, i) => {
    const p = eBack(prog(tau, 0.45 + i * 0.16, 0.8 + i * 0.16));
    const x = P.x + 92 + i * 136, y = P.y + 128;
    if (p <= 0) return;
    ctx.save(); ctx.beginPath(); ctx.arc(x, y, 34 * p, 0, TAU); ctx.fillStyle = s.hex; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = 'rgba(60,60,67,0.18)'; ctx.stroke(); ctx.restore();
    text(s.name, x, y + 76, { size: 21, weight: 500, align: 'center', alpha: eOut(prog(tau, 0.6 + i * 0.16, 0.9 + i * 0.16)) });
    text(s.hex, x, y + 104, { size: 16, fam: F_EN, color: GRAY2, align: 'center', alpha: eOut(prog(tau, 0.7 + i * 0.16, 1.0 + i * 0.16)) });
  });
  const capA = eOut(prog(tau, 1.65, 2.05));
  const capChars = Array.from(SAVE_TITLE), capN = Math.floor(capChars.length * eOut(prog(tau, 1.65, 2.2)));
  text(capChars.slice(0, capN).join(''), P.x + 32, P.y + 300, { size: 34, weight: 700, alpha: capA });
  text('CIE Lab 색공간에서 가장 가까운 50가지 한글 감성 색 이름 · 앞의 세 이름이 작품 제목으로 제안된다', 120, 616, { size: 24, color: GRAY, alpha: eOut(prog(tau, 1.9, 2.3)) });
  // 갤러리에 저장 알림 (확대)
  const alA = win(tau, 2.15, 3.75, 0.3, 0.3);
  if (alA > 0) {
    const ax = 300, ay = 668, aw = 560, ah = 270;
    const s = lerp(0.92, 1, eOut(prog(tau, 2.15, 2.45)));
    ctx.save(); ctx.globalAlpha *= alA; ctx.translate(ax + aw / 2, ay + ah / 2); ctx.scale(s, s); ctx.translate(-(ax + aw / 2), -(ay + ah / 2));
    shadow(50, 16, 0.18); rr(ax, ay, aw, ah, 40); ctx.fillStyle = '#FFFFFF'; ctx.fill(); noShadow();
    ctx.lineWidth = 1; ctx.strokeStyle = '#E5E5EA'; ctx.stroke();
    text('갤러리에 저장', ax + aw / 2, ay + 62, { size: 28, weight: 700, align: 'center' });
    rr(ax + 34, ay + 92, aw - 68, 60, 14); ctx.fillStyle = '#F2F2F7'; ctx.fill();
    const fieldN = Math.floor(capChars.length * eOut(prog(tau, 2.35, 2.9)));
    text(capChars.slice(0, fieldN).join(''), ax + 56, ay + 131, { size: 25 });
    if (prog(tau, 2.35, 2.9) < 1 || Math.floor(tau * 2) % 2 === 0) { const cw = measure(capChars.slice(0, fieldN).join(''), 25); ctx.fillStyle = BLUE; ctx.fillRect(ax + 58 + cw, ay + 106, 2.5, 32); }
    const savePress = win(tau, 3.2, 3.5, 0.05, 0.1);
    rr(ax + 34, ay + 182, (aw - 84) / 2, 58, 29); ctx.fillStyle = '#ECECF0'; ctx.fill();
    text('취소', ax + 34 + (aw - 84) / 4, ay + 220, { size: 25, weight: 600, align: 'center' });
    rr(ax + 50 + (aw - 84) / 2, ay + 182, (aw - 84) / 2, 58, 29); ctx.fillStyle = mix(BLUE, '#0051C7', savePress); ctx.fill();
    text('저장', ax + 50 + (aw - 84) * 0.75, ay + 220, { size: 25, weight: 700, align: 'center', color: '#fff' });
    ctx.restore();
    finger(ax + 50 + (aw - 84) * 0.75, ay + 211, win(tau, 3.0, 3.6, 0.1, 0.12), tau > 3.2 && tau < 3.45 ? 1 : 0);
  }
  // 저장 뒤: 이중 영속성 (Core Data 드래프트 / SwiftData 갤러리)
  const pc = [
    ['Core Data', '작업 중인 캔버스', '조작할 때마다 0.8초 디바운스로 자동 저장', '앱을 다시 열어도 도형·변형·색 그대로'],
    ['SwiftData', '갤러리', '저장 버튼으로 명시적으로 보관', '썸네일 · 합성 수식 · 팔레트 서명 · 색까지'],
  ];
  pc.forEach(([tech, title, l1, l2], i) => {
    const al = eOut(prog(tau, 3.85 + i * 0.25, 4.3 + i * 0.25));
    if (al <= 0) return;
    const x = 120 + i * 515, y = 668 + (1 - al) * 20, w = 495, h = 250;
    ctx.save(); ctx.globalAlpha *= al; rr(x, y, w, h, 22); ctx.fillStyle = '#F4F4F7'; ctx.fill();
    ctx.font = font(24, 700, F_EN); const tw = ctx.measureText(tech).width;
    rr(x + 30, y + 30, tw + 32, 44, 22); ctx.fillStyle = i === 0 ? '#EDE7F6' : '#FDE7EF'; ctx.fill();
    text(tech, x + 46, y + 61, { size: 24, weight: 700, fam: F_EN, color: i === 0 ? BR1 : BR2 });
    text(title, x + 30, y + 128, { size: 34, weight: 700 });
    text(l1, x + 30, y + 178, { size: 23, color: GRAY });
    text(l2, x + 30, y + 214, { size: 23, color: GRAY });
    ctx.restore();
  });
  // 오른쪽: 아이폰 — 갤러리 그리드 → 상세 화면
  const phA = eOut(prog(tau, 0.3, 0.8));
  const detIn = prog(tau, 4.55, 5.0);
  phoneFrame(PHONE.cx + (1 - phA) * 60, PHONE.cy, PHONE.h, phA, (sw2, sh2) => {
    galleryScreen(sw2, sh2, tau);
    if (detIn > 0) detailSheet(sw2, sh2, tau, detIn);
  });
  // 손가락: 새 썸네일 탭 → "캔버스로 열기"
  const bz = 12, k = PHONE.h / (852 + bz * 2), ox = PHONE.cx - ((393 + 24) * k) / 2 + bz * k, oy = PHONE.cy - ((852 + 24) * k) / 2 + bz * k;
  const cw = (393 - 44) / 2;
  finger(ox + (16 + cw / 2) * k, oy + (176 + cw / 2) * k, win(tau, 4.2, 4.65, 0.1, 0.12), tau > 4.33 && tau < 4.55 ? 1 : 0);
  finger(ox + 318 * k, oy + (58 + 36) * k, win(tau, 5.75, 6.4, 0.1, 0.12), tau > 5.95 && tau < 6.25 ? 1 : 0);
  captions(tau, [
    [0.4, 3.6, '색은 수식 밖에서 — 캔버스에 쓰인 색들이 "팔레트 서명"이라는 이름이 된다'],
    [3.6, 6.8, '갤러리의 작품을 열면 합성 수식 · 팔레트 서명 — "캔버스로 열기"로 색까지 그대로 복원'],
  ]);
  ctx.restore();
  fadeOverlay(a);
}

// ───────────────────────── 프레임
window.DURATION = DURATION;
window.renderFrame = function (t) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1; ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, W, H);
  sceneTitle(t); scene1(t); scene2(t); scene3(t); scene4(t); sceneOutro(t);
};
const IMG = {};
window.ready = new Promise((res) => {
  const im = new Image();
  im.onload = () => { IMG.icon = im; res(); };
  im.onerror = () => res();
  im.src = '../../../MathSketch/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png';
}).then(() => document.fonts.ready);
