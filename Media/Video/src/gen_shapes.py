# 앱의 ShapeKind.swift 에서 도형 이름·분류·매개변수 스키마·formulaExpression 문자열을 그대로 뽑아 shapes.gen.js 를 만든다.
# 사용: python3 gen_shapes.py ../../../MathSketch/SketchEngine/ShapeKind.swift > shapes.gen.js
import re, sys, json
src = open(sys.argv[1], encoding='utf-8').read()

def block_after(marker, start=0):
    i = src.index(marker, start)
    j = src.index('{', i)
    depth = 0
    for k in range(j, len(src)):
        if src[k] == '{': depth += 1
        elif src[k] == '}':
            depth -= 1
            if depth == 0: return src[j+1:k], k
    raise SystemExit('unbalanced')

def conv_interp(s):
    out = []; i = 0
    while i < len(s):
        if s.startswith('\\(', i):
            depth = 1; k = i + 2
            while depth:
                if s[k] == '(': depth += 1
                elif s[k] == ')': depth -= 1
                k += 1
            inner = s[i+2:k-1]
            inner = re.sub(r'Int\((.*)\)$', r'Math.trunc(\1)', inner)
            out.append('${' + inner + '}'); i = k
        else:
            out.append(s[i]); i += 1
    return ''.join(out)

# ---- displayName / category
names = dict(re.findall(r'case \.(\w+): return "([^"]+)"', block_after('var displayName: String')[0]))
cat_block = block_after('var category: ShapeCategory')[0]
cats = {}
for m in re.finditer(r'case ([^:]+): return \.(\w+)', cat_block):
    for k in re.findall(r'\.(\w+)', m.group(1)): cats[k] = m.group(2)
cat_names = dict(re.findall(r'case (\w+) = "([^"]+)"', src))
order = re.search(r'case point, line, plane(.*?)\n\n', src, re.S).group(0)
kinds = re.findall(r'\b(\w+)\b', order.replace('case', ''))

# ---- schema
sch_block = block_after('var parameterSchema: [ShapeParameterSpec]')[0]
schema = {}
for m in re.finditer(r'case ([^:]+):\s*return \[(.*?)\]\n', sch_block, re.S):
    ks = re.findall(r'\.(\w+)', m.group(1))
    specs = []
    for s in re.finditer(r'\.init\(name: "(\w+)", defaultValue: ([^,]+), range: (.+?)\)(?=,\s*\n|\s*$|,\s*\.init|\])', m.group(2), re.S):
        name, dv, rg = s.group(1), s.group(2).strip(), s.group(3).strip()
        def num(x):
            x = x.strip().replace('(', '').replace(')', '')
            x = x.replace('.pi', 'Math.PI')
            return x
        lo, hi = rg.split('...')
        specs.append([name, num(dv), num(lo), num(hi)])
    for k in ks: schema[k] = specs

# ---- formulaExpression
fe_block = block_after('func formulaExpression(params rawParams')[0]
sw = fe_block[fe_block.index('switch self {'):]
cases = re.split(r'\n\s*case \.', sw)[1:]
js_cases = []
for c in cases:
    head, body = c.split(':', 1)
    lines = [l.strip() for l in body.strip().splitlines() if l.strip() and l.strip() != '}']
    jl = []
    for l in lines:
        if l.startswith('let '):
            jl.append('const ' + l[4:] + ';')
        elif l.startswith('return "'):
            s = l[len('return "'):-1]
            jl.append('return `' + conv_interp(s) + '`;')
        else:
            raise SystemExit('unexpected line: ' + l)
    js_cases.append(f"    case '{head.strip()}': {{ " + ' '.join(jl) + ' }')

out = []
out.append('// AUTO-GENERATED from MathSketch/SketchEngine/ShapeKind.swift by Media/Video/src/gen_shapes.py — do not edit by hand.')
out.append('var MSGEN = (typeof globalThis !== "undefined" ? globalThis : window).MSGEN = {};')
out.append('MSGEN.KINDS = ' + json.dumps(kinds) + ';')
out.append('MSGEN.DISPLAY_NAME = ' + json.dumps(names, ensure_ascii=False) + ';')
out.append('MSGEN.CATEGORY_OF = ' + json.dumps(cats) + ';')
out.append('MSGEN.CATEGORY_NAME = ' + json.dumps(cat_names, ensure_ascii=False) + ';')
out.append('MSGEN.SCHEMA = {')
for k in kinds:
    out.append(f'  {k}: [' + ', '.join(f'["{n}", {d}, {lo}, {hi}]' for n, d, lo, hi in schema[k]) + '],')
out.append('};')
out.append('MSGEN.formulaExpressionRaw = function (kind, p, n, sweep) {')
out.append('  switch (kind) {')
out.extend(js_cases)
out.append('  }')
out.append('};')
print('\n'.join(out))
