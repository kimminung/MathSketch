// AUTO-GENERATED from MathSketch/SketchEngine/ShapeKind.swift by Media/Video/src/gen_shapes.py — do not edit by hand.
var MSGEN = (typeof globalThis !== "undefined" ? globalThis : window).MSGEN = {};
MSGEN.KINDS = ["point", "line", "plane", "segment", "ray", "polyline", "arc", "quadBezier", "cubicBezier", "circle", "ellipse", "polygon", "star", "sine", "cosine", "lissajous", "spiral", "logSpiral", "rose", "cardioid", "astroid", "epicycloid", "hypocycloid"];
MSGEN.DISPLAY_NAME = {"point": "점", "line": "직선", "plane": "면", "segment": "선분", "ray": "반직선", "polyline": "꺾은선", "arc": "원호", "quadBezier": "2차 베지어", "cubicBezier": "3차 베지어", "circle": "원", "ellipse": "타원", "polygon": "정다각형", "star": "별다각형", "sine": "사인파", "cosine": "코사인파", "lissajous": "리사주 곡선", "spiral": "아르키메데스 나선", "logSpiral": "로그 나선", "rose": "장미 곡선", "cardioid": "카디오이드", "astroid": "아스트로이드", "epicycloid": "에피사이클로이드", "hypocycloid": "하이포사이클로이드"};
MSGEN.CATEGORY_OF = {"point": "basics", "line": "basics", "plane": "basics", "segment": "lines", "ray": "lines", "polyline": "lines", "arc": "lines", "quadBezier": "lines", "cubicBezier": "lines", "circle": "closedShapes", "ellipse": "closedShapes", "polygon": "closedShapes", "star": "closedShapes", "sine": "trig", "cosine": "trig", "lissajous": "trig", "spiral": "polar", "logSpiral": "polar", "rose": "polar", "cardioid": "polar", "astroid": "polar", "epicycloid": "polar", "hypocycloid": "polar"};
MSGEN.CATEGORY_NAME = {"basics": "기본 요소", "lines": "직선류", "closedShapes": "기본 폐도형", "trig": "삼각함수 곡선", "polar": "극좌표/기하 곡선"};
MSGEN.SCHEMA = {
  point: [["x", 0, -2000, 2000], ["y", 0, -2000, 2000]],
  line: [["m", 1, -1000, 1000], ["b", 0, -2000, 2000]],
  plane: [["w", 100, 4, 2000], ["h", 60, 4, 2000]],
  segment: [["x1", -50, -2000, 2000], ["y1", 0, -2000, 2000], ["x2", 50, -2000, 2000], ["y2", 0, -2000, 2000]],
  ray: [["x0", 0, -2000, 2000], ["y0", 0, -2000, 2000], ["angle", 0, -360, 360], ["length", 100, 1, 2000]],
  polyline: [["x1", -50, -2000, 2000], ["y1", 30, -2000, 2000], ["x2", 0, -2000, 2000], ["y2", -30, -2000, 2000], ["x3", 50, -2000, 2000], ["y3", 30, -2000, 2000]],
  arc: [["r", 50, 1, 1000], ["startAngle", 0, -720, 720], ["endAngle", 180, -720, 720]],
  quadBezier: [["cx", 0, -1000, 1000], ["cy", 50, -1000, 1000], ["x1", 50, -1000, 1000], ["y1", 0, -1000, 1000]],
  cubicBezier: [["c1x", -25, -1000, 1000], ["c1y", 55, -1000, 1000], ["c2x", 25, -1000, 1000], ["c2y", -55, -1000, 1000]],
  circle: [["r", 50, 1, 1000]],
  ellipse: [["rx", 50, 1, 1000], ["ry", 30, 1, 1000]],
  polygon: [["sides", 5, 3, 12], ["r", 50, 1, 1000]],
  star: [["points", 5, 3, 12], ["rOuter", 50, 1, 1000], ["rInner", 20, 1, 1000]],
  sine: [["amplitude", 25, 1, 500], ["frequency", 2, 0.1, 10], ["phase", 0, -Math.PI, Math.PI]],
  cosine: [["amplitude", 25, 1, 500], ["frequency", 2, 0.1, 10], ["phase", 0, -Math.PI, Math.PI]],
  lissajous: [["a", 3, 1, 12], ["b", 2, 1, 12], ["delta", Math.PI / 2, -Math.PI, Math.PI], ["scale", 50, 1, 500]],
  spiral: [["a", 5, 0, 100], ["b", 2.5, 0.1, 100], ["turns", 3, 0.25, 12]],
  logSpiral: [["a", 5, 0.1, 100], ["b", 0.19, 0.01, 1], ["turns", 2, 0.25, 8]],
  rose: [["k", 4, 1, 16], ["r", 50, 1, 500]],
  cardioid: [["a", 35, 1, 500]],
  astroid: [["a", 50, 1, 500]],
  epicycloid: [["R", 30, 1, 200], ["r", 10, 1, 200], ["turns", 6, 0.5, 24]],
  hypocycloid: [["R", 50, 1, 200], ["r", 15, 1, 200], ["turns", 6, 0.5, 24]],
};
MSGEN.formulaExpressionRaw = function (kind, p, n, sweep) {
  switch (kind) {
    case 'point': { return `𝑃 = (${n("x")}, ${n("y")})`; }
    case 'line': { return `𝑦 = ${n("m")}·𝑥 + ${n("b")}`; }
    case 'plane': { return `{(𝑥,𝑦) : |𝑥| ≤ ${n("w")}/2, |𝑦| ≤ ${n("h")}/2}`; }
    case 'segment': { return `𝑥(𝑡) = (1−𝑡)·${n("x1")} + 𝑡·${n("x2")}, 𝑦(𝑡) = (1−𝑡)·${n("y1")} + 𝑡·${n("y2")}, 𝑡∈[0,1]`; }
    case 'ray': { return `𝑥(𝑡) = ${n("x0")} + 𝑡·${n("length")}·cos ${n("angle")}°, 𝑦(𝑡) = ${n("y0")} + 𝑡·${n("length")}·sin ${n("angle")}°, 𝑡∈[0,1]`; }
    case 'polyline': { return `⋃ᵢ{(1−𝑡)𝑉ᵢ + 𝑡𝑉ᵢ₊₁ : 𝑡∈[0,1]}, 𝑉₁=(${n("x1")},${n("y1")}), 𝑉₂=(${n("x2")},${n("y2")}), 𝑉₃=(${n("x3")},${n("y3")})`; }
    case 'arc': { return `𝑥(𝑡) = ${n("r")}·cos 𝑡, 𝑦(𝑡) = ${n("r")}·sin 𝑡, 𝑡∈[${n("startAngle")}°,${n("endAngle")}°]`; }
    case 'quadBezier': { return `𝑥(𝑡) = (1−𝑡)²·(−50) + 2(1−𝑡)𝑡·${n("cx")} + 𝑡²·${n("x1")}, 𝑦(𝑡) = (1−𝑡)²·0 + 2(1−𝑡)𝑡·${n("cy")} + 𝑡²·${n("y1")}, 𝑡∈[0,1]`; }
    case 'cubicBezier': { return `𝑥(𝑡) = (1−𝑡)³·(−50) + 3(1−𝑡)²𝑡·${n("c1x")} + 3(1−𝑡)𝑡²·${n("c2x")} + 𝑡³·50, 𝑦(𝑡) = 3(1−𝑡)²𝑡·${n("c1y")} + 3(1−𝑡)𝑡²·${n("c2y")}, 𝑡∈[0,1]`; }
    case 'circle': { return `𝑥(𝑡) = ${n("r")}·cos 𝑡, 𝑦(𝑡) = ${n("r")}·sin 𝑡, 𝑡∈[0,2π]`; }
    case 'ellipse': { return `𝑥(𝑡) = ${n("rx")}·cos 𝑡, 𝑦(𝑡) = ${n("ry")}·sin 𝑡, 𝑡∈[0,2π]`; }
    case 'polygon': { const sides = n("sides"); return `𝑘=⌊${sides}𝑡⌋, 𝑠=${sides}𝑡−𝑘, 𝜃ⱼ=2π𝑗/${sides}−π/2 :  𝑥(𝑡) = ${n("r")}[(1−𝑠)cos 𝜃ₖ + 𝑠·cos 𝜃ₖ₊₁], 𝑦(𝑡) = ${n("r")}[(1−𝑠)sin 𝜃ₖ + 𝑠·sin 𝜃ₖ₊₁], 𝑡∈[0,1]`; }
    case 'star': { const points = n("points"); return `𝑘=⌊2·${points}·𝑡⌋, 𝑠=2·${points}·𝑡−𝑘, 𝑟ⱼ=${n("rOuter")} (𝑗 짝수) 또는 ${n("rInner")} (𝑗 홀수), 𝜃ⱼ=π𝑗/${points}−π/2 :  𝑥(𝑡) = (1−𝑠)𝑟ₖcos 𝜃ₖ + 𝑠𝑟ₖ₊₁cos 𝜃ₖ₊₁, 𝑦(𝑡) = (1−𝑠)𝑟ₖsin 𝜃ₖ + 𝑠𝑟ₖ₊₁sin 𝜃ₖ₊₁`; }
    case 'sine': { return `𝑦 = ${n("amplitude")}·sin(${n("frequency")}·𝑥 + ${n("phase")})`; }
    case 'cosine': { return `𝑦 = ${n("amplitude")}·cos(${n("frequency")}·𝑥 + ${n("phase")})`; }
    case 'lissajous': { return `𝑥(𝑡) = ${n("scale")}·sin(${n("a")}𝑡 + ${n("delta")}), 𝑦(𝑡) = ${n("scale")}·sin(${n("b")}𝑡), 𝑡∈[0,2π]`; }
    case 'spiral': { return `𝑥(θ) = (${n("a")} + ${n("b")}θ)·cos θ, 𝑦(θ) = (${n("a")} + ${n("b")}θ)·sin θ, θ∈[0,${sweep("turns")}]`; }
    case 'logSpiral': { return `𝑥(θ) = ${n("a")}·𝑒^(${n("b")}θ)·cos θ, 𝑦(θ) = ${n("a")}·𝑒^(${n("b")}θ)·sin θ, θ∈[0,${sweep("turns")}]`; }
    case 'rose': { return `𝑥(θ) = ${n("r")}·cos(${Math.trunc(p["k"] ?? 4)}θ)·cos θ, 𝑦(θ) = ${n("r")}·cos(${Math.trunc(p["k"] ?? 4)}θ)·sin θ, θ∈[0,2π]`; }
    case 'cardioid': { return `𝑥(θ) = ${n("a")}(1 − cos θ)cos θ, 𝑦(θ) = ${n("a")}(1 − cos θ)sin θ, θ∈[0,2π]`; }
    case 'astroid': { return `𝑥(θ) = ${n("a")}cos³θ, 𝑦(θ) = ${n("a")}sin³θ, θ∈[0,2π]`; }
    case 'epicycloid': { const R = n("R"), r = n("r"); return `𝑥(θ) = (${R}+${r})cos θ − ${r}·cos(((${R}+${r})/${r})θ), 𝑦(θ) = (${R}+${r})sin θ − ${r}·sin(((${R}+${r})/${r})θ), θ∈[0,${sweep("turns")}]`; }
    case 'hypocycloid': { const R = n("R"), r = n("r"); return `𝑥(θ) = (${R}−${r})cos θ + ${r}·cos(((${R}−${r})/${r})θ), 𝑦(θ) = (${R}−${r})sin θ − ${r}·sin(((${R}−${r})/${r})θ), θ∈[0,${sweep("turns")}]`; }
  }
};
