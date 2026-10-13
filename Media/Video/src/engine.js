// MathSketch 앱의 Swift 엔진을 그대로 옮긴 JS 포트 — 영상 속 도형·수식·색 이름이 앱과 똑같이 나오도록.
//   ShapeKind.samplePoints / resolvedParameters  (SketchEngine/ShapeKind.swift)
//   ElementTransform.apply / clamped             (SketchEngine/ElementTransform.swift)
//   SketchCanvasRenderer.fit (+ line clipping)   (SketchEngine/SketchCanvasRenderer.swift)
//   NumberText.format, FormulaFormatter.label, ArtisticFormulaFormatter.narrative,
//   SketchFormulaFormatter.format, PaletteNamer, PaletteSignature
// formulaExpression 문자열은 gen_shapes.py 가 Swift 원문에서 그대로 뽑아 shapes.gen.js 에 넣는다.
(function (root) {
  'use strict';
  const G = root.MSGEN;
  const PI = Math.PI;
  const MS = {};

  // ---------- NumberText.format (Swift .rounded() = 반올림, 0에서 먼 쪽)
  const roundAway = x => (x < 0 ? -Math.round(-x) : Math.round(x));
  function fmt(value, decimals = 3) {
    const f = Math.pow(10, decimals);
    const rounded = roundAway(value * f) / f;
    if (Number.isInteger(rounded) && Math.abs(rounded) < 1e15) return String(Math.trunc(rounded) || 0);
    let text = rounded.toFixed(decimals);
    while (text.endsWith('0')) text = text.slice(0, -1);
    if (text.endsWith('.')) text = text.slice(0, -1);
    return text;
  }
  MS.fmt = fmt;

  // ---------- ShapeKind
  MS.KINDS = G.KINDS;
  MS.DISPLAY_NAME = G.DISPLAY_NAME;
  MS.CATEGORY_OF = G.CATEGORY_OF;
  MS.CATEGORY_NAME = G.CATEGORY_NAME;
  MS.CATEGORIES = ['basics', 'lines', 'closedShapes', 'trig', 'polar'];
  MS.byCategory = MS.CATEGORIES.map(c => ({ category: c, name: G.CATEGORY_NAME[c], kinds: G.KINDS.filter(k => G.CATEGORY_OF[k] === c) }));

  MS.renderStyle = k => (k === 'point' ? 'point' : k === 'plane' ? 'fill' : 'stroke');
  MS.isClosed = k => ['plane', 'circle', 'ellipse', 'polygon', 'star', 'lissajous', 'rose', 'cardioid', 'astroid'].includes(k);

  function resolved(kind, params = {}) {
    const out = {};
    for (const [name, def, lo, hi] of G.SCHEMA[kind]) {
      const raw = params[name] !== undefined ? params[name] : def;
      out[name] = Number.isFinite(raw) ? Math.min(Math.max(raw, lo), hi) : def;
    }
    return out;
  }
  MS.resolved = resolved;

  function samplePoints(kind, raw, sampleCount = 128) {
    const p = resolved(kind, raw);
    const pts = [];
    const range = (n, f) => { for (let i = 0; i < n; i++) pts.push(f(i)); return pts; };
    switch (kind) {
      case 'point': return [[p.x, p.y]];
      case 'line': {
        const m = p.m, b = p.b, half = 600;
        const len = Math.hypot(1, m); const dx = 1 / len, dy = m / len;
        return [[0 - dx * half, b - dy * half], [0 + dx * half, b + dy * half]];
      }
      case 'plane': { const w = p.w, h = p.h; return [[-w / 2, -h / 2], [w / 2, -h / 2], [w / 2, h / 2], [-w / 2, h / 2], [-w / 2, -h / 2]]; }
      case 'segment': return [[p.x1, p.y1], [p.x2, p.y2]];
      case 'ray': { const a = p.angle * PI / 180; return [[p.x0, p.y0], [p.x0 + Math.cos(a) * p.length, p.y0 + Math.sin(a) * p.length]]; }
      case 'polyline': return [[p.x1, p.y1], [p.x2, p.y2], [p.x3, p.y3]];
      case 'arc': {
        const r = p.r, s = p.startAngle * PI / 180, e = p.endAngle * PI / 180, n = Math.max(sampleCount, 2);
        return range(n, i => { const th = s + (e - s) * i / (n - 1); return [r * Math.cos(th), r * Math.sin(th)]; });
      }
      case 'quadBezier': {
        const p0 = [-50, 0], c = [p.cx, p.cy], p1 = [p.x1, p.y1], n = Math.max(sampleCount, 2);
        return range(n, i => { const t = i / (n - 1), mt = 1 - t; return [mt * mt * p0[0] + 2 * mt * t * c[0] + t * t * p1[0], mt * mt * p0[1] + 2 * mt * t * c[1] + t * t * p1[1]]; });
      }
      case 'cubicBezier': {
        const p0 = [-50, 0], p1 = [50, 0], c1 = [p.c1x, p.c1y], c2 = [p.c2x, p.c2y], n = Math.max(sampleCount, 2);
        return range(n, i => {
          const t = i / (n - 1), mt = 1 - t;
          return [mt * mt * mt * p0[0] + 3 * mt * mt * t * c1[0] + 3 * mt * t * t * c2[0] + t * t * t * p1[0],
                  mt * mt * mt * p0[1] + 3 * mt * mt * t * c1[1] + 3 * mt * t * t * c2[1] + t * t * t * p1[1]];
        });
      }
      case 'circle': { const r = p.r, n = Math.max(sampleCount, 8); return range(n, i => { const th = 2 * PI * i / (n - 1); return [r * Math.cos(th), r * Math.sin(th)]; }); }
      case 'ellipse': { const n = Math.max(sampleCount, 8); return range(n, i => { const th = 2 * PI * i / (n - 1); return [p.rx * Math.cos(th), p.ry * Math.sin(th)]; }); }
      case 'polygon': {
        const sides = Math.max(3, Math.round(p.sides)), r = p.r;
        for (let i = 0; i <= sides; i++) { const th = 2 * PI * i / sides - PI / 2; pts.push([r * Math.cos(th), r * Math.sin(th)]); }
        return pts;
      }
      case 'star': {
        const points = Math.max(3, Math.round(p.points)), count = points * 2;
        for (let i = 0; i <= count; i++) { const th = PI * i / points - PI / 2; const r = i % 2 === 0 ? p.rOuter : p.rInner; pts.push([r * Math.cos(th), r * Math.sin(th)]); }
        return pts;
      }
      case 'sine': case 'cosine': {
        const n = Math.max(sampleCount, 8), width = 100;
        return range(n, i => { const t = i / (n - 1); const ang = p.frequency * 2 * PI * t + p.phase; return [(t - 0.5) * width, p.amplitude * (kind === 'sine' ? Math.sin(ang) : Math.cos(ang))]; });
      }
      case 'lissajous': { const n = Math.max(sampleCount, 8); return range(n, i => { const t = 2 * PI * i / (n - 1); return [p.scale * Math.sin(p.a * t + p.delta), p.scale * Math.sin(p.b * t)]; }); }
      case 'spiral': { const n = Math.max(sampleCount, 8); return range(n, i => { const th = p.turns * 2 * PI * i / (n - 1); const r = p.a + p.b * th; return [r * Math.cos(th), r * Math.sin(th)]; }); }
      case 'logSpiral': { const n = Math.max(sampleCount, 8); return range(n, i => { const th = p.turns * 2 * PI * i / (n - 1); const r = p.a * Math.exp(p.b * th); return [r * Math.cos(th), r * Math.sin(th)]; }); }
      case 'rose': { const n = Math.max(sampleCount, 8); return range(n, i => { const th = 2 * PI * i / (n - 1); const rr = p.r * Math.cos(p.k * th); return [rr * Math.cos(th), rr * Math.sin(th)]; }); }
      case 'cardioid': { const n = Math.max(sampleCount, 8); return range(n, i => { const th = 2 * PI * i / (n - 1); const r = p.a * (1 - Math.cos(th)); return [r * Math.cos(th), r * Math.sin(th)]; }); }
      case 'astroid': { const n = Math.max(sampleCount, 8); return range(n, i => { const th = 2 * PI * i / (n - 1); return [p.a * Math.pow(Math.cos(th), 3), p.a * Math.pow(Math.sin(th), 3)]; }); }
      case 'epicycloid': {
        const R = p.R, r = p.r, n = Math.max(sampleCount, 8);
        return range(n, i => { const th = p.turns * 2 * PI * i / (n - 1); return [(R + r) * Math.cos(th) - r * Math.cos((R + r) / r * th), (R + r) * Math.sin(th) - r * Math.sin((R + r) / r * th)]; });
      }
      case 'hypocycloid': {
        const R = p.R, r = p.r, n = Math.max(sampleCount, 8);
        return range(n, i => { const th = p.turns * 2 * PI * i / (n - 1); return [(R - r) * Math.cos(th) + r * Math.cos((R - r) / r * th), (R - r) * Math.sin(th) - r * Math.sin((R - r) / r * th)]; });
      }
    }
    throw new Error('unknown kind ' + kind);
  }
  MS.samplePoints = samplePoints;

  MS.formulaExpression = function (kind, raw = {}) {
    const p = resolved(kind, raw);
    const n = key => fmt(p[key] !== undefined ? p[key] : 0);
    const sweep = key => fmt((p[key] !== undefined ? p[key] : 1) * 2 * PI);
    return G.formulaExpressionRaw(kind, p, n, sweep);
  };

  // ---------- ElementTransform  P' = R(θ)·Sh(shx,shy)·S(sx,sy)·P + T
  MS.identity = () => ({ tx: 0, ty: 0, sx: 1, sy: 1, rot: 0, shx: 0, shy: 0 });
  MS.SCALE_RANGE = [0.1, 8.0];
  MS.SHEAR_RANGE = [-1.0, 1.0];
  function applyT(t, points, forPoint = false) {
    const th = t.rot * PI / 180, c = Math.cos(th), s = Math.sin(th);
    return points.map(([px, py]) => {
      let x = px, y = py;
      if (!forPoint) {
        x *= t.sx; y *= t.sy;
        const shX = x + t.shx * y, shY = y + t.shy * x; x = shX; y = shY;
        const rx = x * c - y * s, ry = x * s + y * c; x = rx; y = ry;
      }
      return [x + t.tx, y + t.ty];
    });
  }
  MS.applyTransform = applyT;
  function applyDir(t, [dx0, dy0]) {
    let x = dx0 * t.sx, y = dy0 * t.sy;
    const shX = x + t.shx * y, shY = y + t.shy * x; x = shX; y = shY;
    const th = t.rot * PI / 180, c = Math.cos(th), s = Math.sin(th);
    return [x * c - y * s, x * s + y * c];
  }
  function wrapDeg(d) { d = d % 360; if (d > 180) d -= 360; if (d < -180) d += 360; return d; }
  MS.clampTransform = function (t) {
    const cl = (v, [lo, hi]) => Math.min(Math.max(v, lo), hi);
    return { ...t, sx: cl(t.sx, MS.SCALE_RANGE), sy: cl(t.sy, MS.SCALE_RANGE), shx: cl(t.shx, MS.SHEAR_RANGE), shy: cl(t.shy, MS.SHEAR_RANGE), rot: wrapDeg(t.rot) };
  };

  // ---------- SketchElement
  let uid = 0;
  MS.element = function (kind, opts = {}) {
    return {
      id: opts.id || ('e' + (++uid)),
      kind,
      params: resolved(kind, opts.params || {}),
      t: { ...MS.identity(), ...(opts.t || {}) },
      color: opts.color || '#1C1C1E', // ElementColor.defaultNeutral (숯빛 검정)
      z: opts.z || 0,
    };
  };
  MS.localPoints = (el, n = 128) => samplePoints(el.kind, el.params, n);
  MS.worldPoints = (el, n = 128) => applyT(el.t, MS.localPoints(el, n), el.kind === 'point');

  // ---------- SketchCanvasRenderer.fit
  function bbox(points) {
    if (!points.length) return null;
    let minX = points[0][0], maxX = minX, minY = points[0][1], maxY = minY;
    for (const [x, y] of points) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
    return { x: minX, y: minY, w: maxX - minX, h: maxY - minY };
  }
  MS.bbox = bbox;
  function fitContext(worldPts, rect) {
    const box = bbox(worldPts) || { x: -100, y: -100, w: 200, h: 200 };
    const minExtent = 40;
    const scale = Math.min(rect.w / Math.max(box.w, minExtent), rect.h / Math.max(box.h, minExtent)) * 0.92;
    const bcx = box.x + box.w / 2, bcy = box.y + box.h / 2;
    const vcx = rect.x + rect.w / 2, vcy = rect.y + rect.h / 2;
    return {
      scale,
      toView: ([x, y]) => [vcx + (x - bcx) * scale, vcy - (y - bcy) * scale],
      toWorld: ([x, y]) => (scale > 0 ? [bcx + (x - vcx) / scale, bcy - (y - vcy) / scale] : [bcx, bcy]),
    };
  }
  MS.fitContext = function (elements, rect, n = 128) {
    return fitContext(elements.filter(e => e.kind !== 'line').flatMap(e => MS.worldPoints(e, n)), rect);
  };
  function clipLine([px, py], [dx, dy], rect) {
    const checks = [[-dx, px - rect.x], [dx, rect.x + rect.w - px], [-dy, py - rect.y], [dy, rect.y + rect.h - py]];
    let tMin = -Infinity, tMax = Infinity;
    for (const [p, q] of checks) {
      if (p === 0) { if (q < 0) return null; }
      else { const t = q / p; if (p < 0) tMin = Math.max(tMin, t); else tMax = Math.min(tMax, t); }
    }
    if (tMin > tMax) return null;
    return [[px + tMin * dx, py + tMin * dy], [px + tMax * dx, py + tMax * dy]];
  }
  // rect = {x,y,w,h} in view space. Returns [{el, pts}] sorted by z.
  MS.fit = function (elements, rect, n = 128, ctxOverride) {
    if (rect.w <= 0 || rect.h <= 0) return [];
    const bounded = elements.filter(e => e.kind !== 'line');
    const world = bounded.map(e => [e, MS.worldPoints(e, n)]);
    const ctx = ctxOverride || fitContext(world.flatMap(w => w[1]), rect);
    const out = world.map(([e, pts]) => ({ el: e, pts: pts.map(ctx.toView) }));
    for (const e of elements) {
      if (e.kind !== 'line') continue;
      const m = e.params.m, b = e.params.b;
      const anchorW = applyT(e.t, [[0, b]])[0];
      const l = Math.hypot(1, m);
      const dW = applyDir(e.t, [1 / l, m / l]);
      const anchorV = ctx.toView(anchorW);
      let dvx = dW[0] * ctx.scale, dvy = -dW[1] * ctx.scale; const dl = Math.hypot(dvx, dvy) || 1; dvx /= dl; dvy /= dl;
      const seg = clipLine(anchorV, [dvx, dvy], rect);
      if (seg) out.push({ el: e, pts: seg });
    }
    out.sort((a, b) => a.el.z - b.el.z);
    out.ctx = ctx;
    return out;
  };

  // ---------- 수식 표기
  MS.label = function (el) { // FormulaFormatter.label
    const parts = [MS.formulaExpression(el.kind, el.params)];
    const t = el.t;
    if (t.sx !== 1 || t.sy !== 1) parts.push(`scale(${fmt(t.sx)}, ${fmt(t.sy)})`);
    if (t.rot !== 0) parts.push(`rotate(${fmt(t.rot)})`);
    if (t.shx !== 0 || t.shy !== 0) parts.push(`shear(${fmt(t.shx)}, ${fmt(t.shy)})`);
    if (t.tx !== 0 || t.ty !== 0) parts.push(`translate(${fmt(t.tx)}, ${fmt(t.ty)})`);
    return parts.join(' · ');
  };
  const SUB = { 0: '₀', 1: '₁', 2: '₂', 3: '₃', 4: '₄', 5: '₅', 6: '₆', 7: '₇', 8: '₈', 9: '₉' };
  MS.subscript = n => String(n).split('').map(c => SUB[c]).join('');
  MS.transformAnnotation = function (t) {
    const parts = [];
    if (t.sx !== 1 || t.sy !== 1) parts.push(`배율 ${fmt(t.sx)}×${fmt(t.sy)}`);
    if (t.rot !== 0) parts.push(`회전 ${fmt(t.rot)}°`);
    if (t.shx !== 0 || t.shy !== 0) parts.push(`비틀기 (${fmt(t.shx)}, ${fmt(t.shy)})`);
    if (t.tx !== 0 || t.ty !== 0) parts.push(`이동 (${fmt(t.tx)}, ${fmt(t.ty)})`);
    return parts.join(', ');
  };
  // ArtisticFormulaFormatter.narrative → { header, lines:[{label, equation, annotation, el}] } (+ .text 원문)
  MS.narrative = function (elements) {
    if (!elements.length) return null;
    const sorted = [...elements].sort((a, b) => a.z - b.z);
    const header = '이 그림을 이루는 점들의 집합:';
    const lines = sorted.map((el, i) => {
      const label = sorted.length > 1 ? `𝑃${MS.subscript(i + 1)}(𝑡) : ` : '𝑃(𝑡) : ';
      const equation = MS.formulaExpression(el.kind, el.params);
      const annotation = MS.transformAnnotation(el.t);
      return { label, equation, annotation, el };
    });
    const text = [header, ...lines.map(l => (l.annotation ? `  ${l.label}${l.equation}   —  ${l.annotation}` : `  ${l.label}${l.equation}`))].join('\n');
    return { header, lines, text };
  };
  // SketchFormulaFormatter.format
  MS.dslElement = function (el) {
    let text = `${el.kind}(${G.SCHEMA[el.kind].map(([name, def]) => `${name}: ${fmt(el.params[name] !== undefined ? el.params[name] : def)}`).join(', ')})`;
    const t = el.t;
    if (t.sx !== 1 || t.sy !== 1) text += ` · scale(${fmt(t.sx)}, ${fmt(t.sy)})`;
    if (t.rot !== 0) text += ` · rotate(${fmt(t.rot)})`;
    if (t.shx !== 0 || t.shy !== 0) text += ` · shear(${fmt(t.shx)}, ${fmt(t.shy)})`;
    if (t.tx !== 0 || t.ty !== 0) text += ` · translate(${fmt(t.tx)}, ${fmt(t.ty)})`;
    return text;
  };
  MS.dsl = elements => [...elements].sort((a, b) => a.z - b.z).map(MS.dslElement).join(' + ');

  // ---------- PaletteNamer (CIE Lab 최근접) / PaletteSignature
  MS.PALETTE_CATALOG = [
    ['노을빛 주황', '#FF6B35'], ['심해 남색', '#0B3D64'], ['라임 그린', '#A8E05F'], ['서리 라벤더', '#C9B8E8'],
    ['벚꽃 분홍', '#F7C9D1'], ['쪽빛 파랑', '#1E3A8A'], ['가을 갈색', '#8B5E34'], ['숯빛 검정', '#1C1C1E'],
    ['진주 흰색', '#F5F3EE'], ['민트 그린', '#3EB89B'], ['레몬 옐로', '#F4D35E'], ['산호 빨강', '#FF5A5F'],
    ['자두 보라', '#6B3FA0'], ['청록', '#0E7C7B'], ['모래빛 베이지', '#D8C3A5'], ['와인 레드', '#6B1E2B'],
    ['하늘빛 파랑', '#6EC6FF'], ['올리브 그린', '#708238'], ['코코아 브라운', '#4B3621'], ['복숭아 살구색', '#FFB199'],
    ['청보라', '#4B4E9E'], ['은빛 회색', '#B8B8B8'], ['다홍', '#E3432D'], ['연두', '#9ACD32'],
    ['짙은 에메랄드', '#046241'], ['황금빛', '#D4AF37'], ['자홍', '#C2185B'], ['담청색', '#4FA3D1'],
    ['적갈색', '#8C3A2B'], ['청자색', '#4A6670'], ['플럼 핑크', '#D982B5'], ['미드나잇 블루', '#003366'],
    ['토파즈 옐로', '#FFC94A'], ['라일락', '#C8A2C8'], ['버건디', '#800020'], ['아이보리', '#FFFFF0'],
    ['카키', '#8B8B5A'], ['터콰이즈', '#2FBFB0'], ['라즈베리', '#E30B5D'], ['세이지 그린', '#9CAF88'],
    ['초콜릿 브라운', '#3B2412'], ['피치 핑크', '#FFD9C9'], ['코발트 블루', '#0047AB'], ['머스터드 옐로', '#D9A441'],
    ['자스민 화이트', '#F8F4E3'], ['딥 퍼플', '#4B0082'], ['스카이 민트', '#B9EBD0'], ['로즈 골드', '#B76E79'],
    ['페리윙클', '#9BA5E0'], ['차콜 그레이', '#36454F'],
  ];
  const hexRGB = hex => { const v = parseInt(hex.replace('#', ''), 16); return [((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255]; };
  function lab([r, g, b]) {
    const lin = c => (c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
    const rl = lin(r), gl = lin(g), bl = lin(b);
    const x = rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375;
    const y = rl * 0.2126729 + gl * 0.7151522 + bl * 0.0721750;
    const z = rl * 0.0193339 + gl * 0.1191920 + bl * 0.9503041;
    const f = t => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
    const fx = f(x / 0.95047), fy = f(y / 1.0), fz = f(z / 1.08883);
    return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }
  MS.paletteName = function (hex) {
    const tl = lab(hexRGB(hex));
    let best = MS.PALETTE_CATALOG[0], bestD = Infinity;
    for (const c of MS.PALETTE_CATALOG) {
      const l2 = lab(hexRGB(c[1]));
      const d = Math.hypot(tl[0] - l2[0], tl[1] - l2[1], tl[2] - l2[2]);
      if (d < bestD) { bestD = d; best = c; }
    }
    return best[0];
  };
  // ElementColor.hex 는 대문자 #RRGGBB
  MS.normHex = hex => '#' + hex.replace('#', '').toUpperCase();
  MS.swatches = function (elements) {
    const seen = new Set(), out = [];
    for (const el of [...elements].sort((a, b) => a.z - b.z)) {
      const hex = MS.normHex(el.color);
      if (seen.has(hex)) continue;
      seen.add(hex);
      out.push({ hex, name: MS.paletteName(hex) });
    }
    return out;
  };
  MS.caption = (elements, maxNames = 3) => MS.swatches(elements).slice(0, maxNames).map(s => s.name).join(' · ');

  root.MS = MS;
  if (typeof module !== 'undefined' && module.exports) module.exports = MS;
})(typeof globalThis !== 'undefined' ? globalThis : window);
