// Generate reference outputs for Renderer using source TS compiled to JS
// First build the rough package, then use it
import { execSync } from 'child_process';

// Build rough.js first
try {
  execSync('cd /Users/julik/Code/libs/roughrb/tmp/rough && npx rollup -c', { stdio: 'pipe' });
} catch(e) {
  // If rollup config doesn't exist, try tsc
  try {
    execSync('cd /Users/julik/Code/libs/roughrb/tmp/rough && npx tsc', { stdio: 'pipe' });
  } catch(e2) {
    // ignore
  }
}

// Use the generator.ts functions via dynamic import after tsc build
// Actually let's just write a standalone script that recreates the key renderer functions
// This is more reliable than trying to build the whole package

// Import the individual compiled libs
import { parsePath, absolutize, normalize } from '../../tmp/rough/node_modules/path-data-parser/lib/index.js';
import { pointsOnBezierCurves } from '../../tmp/rough/node_modules/points-on-curve/lib/index.js';
import { curveToBezier } from '../../tmp/rough/node_modules/points-on-curve/lib/curve-to-bezier.js';
import { hachureLines } from '../../tmp/rough/node_modules/hachure-fill/bin/hachure.js';

// Inline the Random class
class Random {
  constructor(seed) { this.seed = seed; }
  next() {
    if (this.seed) {
      return ((2 ** 31 - 1) & (this.seed = Math.imul(48271, this.seed))) / 2 ** 31;
    }
    return Math.random();
  }
}

// Inline the core renderer functions (from renderer.ts)
function random(ops) {
  if (!ops.randomizer) { ops.randomizer = new Random(ops.seed || 0); }
  return ops.randomizer.next();
}

function _offset(min, max, ops, roughnessGain = 1) {
  return ops.roughness * roughnessGain * ((random(ops) * (max - min)) + min);
}

function _offsetOpt(x, ops, roughnessGain = 1) {
  return _offset(-x, x, ops, roughnessGain);
}

function cloneOptionsAlterSeed(ops) {
  const result = { ...ops };
  result.randomizer = undefined;
  if (ops.seed) { result.seed = ops.seed + 1; }
  return result;
}

function _line(x1, y1, x2, y2, o, move, overlay) {
  const lengthSq = (x1 - x2) ** 2 + (y1 - y2) ** 2;
  const length = Math.sqrt(lengthSq);
  let roughnessGain = 1;
  if (length < 200) { roughnessGain = 1; }
  else if (length > 500) { roughnessGain = 0.4; }
  else { roughnessGain = (-0.0016668) * length + 1.233334; }

  let offset = o.maxRandomnessOffset || 0;
  if ((offset * offset * 100) > lengthSq) { offset = length / 10; }
  const halfOffset = offset / 2;
  const divergePoint = 0.2 + random(o) * 0.2;
  let midDispX = o.bowing * o.maxRandomnessOffset * (y2 - y1) / 200;
  let midDispY = o.bowing * o.maxRandomnessOffset * (x1 - x2) / 200;
  midDispX = _offsetOpt(midDispX, o, roughnessGain);
  midDispY = _offsetOpt(midDispY, o, roughnessGain);
  const ops = [];
  const randomHalf = () => _offsetOpt(halfOffset, o, roughnessGain);
  const randomFull = () => _offsetOpt(offset, o, roughnessGain);
  const preserveVertices = o.preserveVertices;
  if (move) {
    if (overlay) {
      ops.push({ op: 'move', data: [x1 + (preserveVertices ? 0 : randomHalf()), y1 + (preserveVertices ? 0 : randomHalf())] });
    } else {
      ops.push({ op: 'move', data: [x1 + (preserveVertices ? 0 : _offsetOpt(offset, o, roughnessGain)), y1 + (preserveVertices ? 0 : _offsetOpt(offset, o, roughnessGain))] });
    }
  }
  if (overlay) {
    ops.push({ op: 'bcurveTo', data: [
      midDispX + x1 + (x2 - x1) * divergePoint + randomHalf(),
      midDispY + y1 + (y2 - y1) * divergePoint + randomHalf(),
      midDispX + x1 + 2 * (x2 - x1) * divergePoint + randomHalf(),
      midDispY + y1 + 2 * (y2 - y1) * divergePoint + randomHalf(),
      x2 + (preserveVertices ? 0 : randomHalf()),
      y2 + (preserveVertices ? 0 : randomHalf()),
    ]});
  } else {
    ops.push({ op: 'bcurveTo', data: [
      midDispX + x1 + (x2 - x1) * divergePoint + randomFull(),
      midDispY + y1 + (y2 - y1) * divergePoint + randomFull(),
      midDispX + x1 + 2 * (x2 - x1) * divergePoint + randomFull(),
      midDispY + y1 + 2 * (y2 - y1) * divergePoint + randomFull(),
      x2 + (preserveVertices ? 0 : randomFull()),
      y2 + (preserveVertices ? 0 : randomFull()),
    ]});
  }
  return ops;
}

function _doubleLine(x1, y1, x2, y2, o, filling = false) {
  const singleStroke = filling ? o.disableMultiStrokeFill : o.disableMultiStroke;
  const o1 = _line(x1, y1, x2, y2, o, true, false);
  if (singleStroke) { return o1; }
  const o2 = _line(x1, y1, x2, y2, o, true, true);
  return o1.concat(o2);
}

function _curve(points, closePoint, o) {
  const len = points.length;
  const ops = [];
  if (len > 3) {
    const b = [];
    const s = 1 - o.curveTightness;
    ops.push({ op: 'move', data: [points[1][0], points[1][1]] });
    for (let i = 1; (i + 2) < len; i++) {
      const cachedVertArray = points[i];
      b[0] = [cachedVertArray[0], cachedVertArray[1]];
      b[1] = [cachedVertArray[0] + (s * points[i + 1][0] - s * points[i - 1][0]) / 6, cachedVertArray[1] + (s * points[i + 1][1] - s * points[i - 1][1]) / 6];
      b[2] = [points[i + 1][0] + (s * points[i][0] - s * points[i + 2][0]) / 6, points[i + 1][1] + (s * points[i][1] - s * points[i + 2][1]) / 6];
      b[3] = [points[i + 1][0], points[i + 1][1]];
      ops.push({ op: 'bcurveTo', data: [b[1][0], b[1][1], b[2][0], b[2][1], b[3][0], b[3][1]] });
    }
    if (closePoint && closePoint.length === 2) {
      const ro = o.maxRandomnessOffset;
      ops.push({ op: 'lineTo', data: [closePoint[0] + _offsetOpt(ro, o), closePoint[1] + _offsetOpt(ro, o)] });
    }
  } else if (len === 3) {
    ops.push({ op: 'move', data: [points[1][0], points[1][1]] });
    ops.push({ op: 'bcurveTo', data: [points[1][0], points[1][1], points[2][0], points[2][1], points[2][0], points[2][1]] });
  } else if (len === 2) {
    ops.push(..._line(points[0][0], points[0][1], points[1][0], points[1][1], o, true, true));
  }
  return ops;
}

function _computeEllipsePoints(increment, cx, cy, rx, ry, offset, overlap, o) {
  const coreOnly = o.roughness === 0;
  const corePoints = [];
  const allPoints = [];

  if (coreOnly) {
    increment = increment / 4;
    allPoints.push([cx + rx * Math.cos(-increment), cy + ry * Math.sin(-increment)]);
    for (let angle = 0; angle <= Math.PI * 2; angle += increment) {
      const p = [cx + rx * Math.cos(angle), cy + ry * Math.sin(angle)];
      corePoints.push(p);
      allPoints.push(p);
    }
    allPoints.push([cx + rx * Math.cos(0), cy + ry * Math.sin(0)]);
    allPoints.push([cx + rx * Math.cos(increment), cy + ry * Math.sin(increment)]);
  } else {
    const radOffset = _offsetOpt(0.5, o) - (Math.PI / 2);
    allPoints.push([
      _offsetOpt(offset, o) + cx + 0.9 * rx * Math.cos(radOffset - increment),
      _offsetOpt(offset, o) + cy + 0.9 * ry * Math.sin(radOffset - increment),
    ]);
    const endAngle = Math.PI * 2 + radOffset - 0.01;
    for (let angle = radOffset; angle < endAngle; angle += increment) {
      const p = [_offsetOpt(offset, o) + cx + rx * Math.cos(angle), _offsetOpt(offset, o) + cy + ry * Math.sin(angle)];
      corePoints.push(p);
      allPoints.push(p);
    }
    allPoints.push([
      _offsetOpt(offset, o) + cx + rx * Math.cos(radOffset + Math.PI * 2 + overlap * 0.5),
      _offsetOpt(offset, o) + cy + ry * Math.sin(radOffset + Math.PI * 2 + overlap * 0.5),
    ]);
    allPoints.push([
      _offsetOpt(offset, o) + cx + 0.98 * rx * Math.cos(radOffset + overlap),
      _offsetOpt(offset, o) + cy + 0.98 * ry * Math.sin(radOffset + overlap),
    ]);
    allPoints.push([
      _offsetOpt(offset, o) + cx + 0.9 * rx * Math.cos(radOffset + overlap * 0.5),
      _offsetOpt(offset, o) + cy + 0.9 * ry * Math.sin(radOffset + overlap * 0.5),
    ]);
  }
  return [allPoints, corePoints];
}

// Default options
const defaultOpts = {
  maxRandomnessOffset: 2,
  roughness: 1,
  bowing: 1,
  stroke: '#000',
  strokeWidth: 1,
  curveTightness: 0,
  curveFitting: 0.95,
  curveStepCount: 9,
  fillStyle: 'hachure',
  fillWeight: -1,
  hachureAngle: -41,
  hachureGap: -1,
  dashOffset: -1,
  dashGap: -1,
  zigzagOffset: -1,
  seed: 0,
  disableMultiStroke: false,
  disableMultiStrokeFill: false,
  preserveVertices: false,
  fillShapeRoughnessGain: 0.8,
};

function makeOpts(overrides = {}) {
  return { ...defaultOpts, ...overrides };
}

const result = {};

// Test line
const lineOpts = makeOpts({ seed: 42 });
result.line = {
  input: { x1: 0, y1: 0, x2: 100, y2: 100 },
  ops: _doubleLine(0, 0, 100, 100, lineOpts),
};

// Test rectangle (as polygon)
const rectOpts = makeOpts({ seed: 42 });
const rectPoints = [[10, 10], [210, 10], [210, 110], [10, 110]];
const rectOps = [];
for (let i = 0; i < rectPoints.length; i++) {
  const next = (i + 1) % rectPoints.length;
  rectOps.push(..._doubleLine(rectPoints[i][0], rectPoints[i][1], rectPoints[next][0], rectPoints[next][1], rectOpts));
}
result.rectangle = {
  input: { x: 10, y: 10, width: 200, height: 100 },
  ops: rectOps,
};

// Test ellipse
const ellipseOpts = makeOpts({ seed: 42 });
const psq = Math.sqrt(Math.PI * 2 * Math.sqrt(((150/2)**2 + (100/2)**2) / 2));
const stepCount = Math.ceil(Math.max(ellipseOpts.curveStepCount, (ellipseOpts.curveStepCount / Math.sqrt(200)) * psq));
const increment = (Math.PI * 2) / stepCount;
let erx = Math.abs(150 / 2);
let ery = Math.abs(100 / 2);
const curveFitRandomness = 1 - ellipseOpts.curveFitting;
erx += _offsetOpt(erx * curveFitRandomness, ellipseOpts);
ery += _offsetOpt(ery * curveFitRandomness, ellipseOpts);
const [ap1, cp1] = _computeEllipsePoints(increment, 100, 100, erx, ery, 1, increment * _offset(0.1, _offset(0.4, 1, ellipseOpts), ellipseOpts), ellipseOpts);
let eo1 = _curve(ap1, null, ellipseOpts);
const [ap2] = _computeEllipsePoints(increment, 100, 100, erx, ery, 1.5, 0, ellipseOpts);
const eo2 = _curve(ap2, null, ellipseOpts);
eo1 = eo1.concat(eo2);
result.ellipse = {
  input: { cx: 100, cy: 100, width: 150, height: 100 },
  ops: eo1,
  estimated_points: cp1,
};

// SVG path
const svgOpts = makeOpts({ seed: 42 });
const segments = normalize(absolutize(parsePath("M 10 80 C 40 10, 65 10, 95 80")));
const svgOps = [];
let first = [0, 0];
let current = [0, 0];
for (const { key, data } of segments) {
  switch (key) {
    case 'M':
      current = [data[0], data[1]];
      first = [data[0], data[1]];
      break;
    case 'L':
      svgOps.push(..._doubleLine(current[0], current[1], data[0], data[1], svgOpts));
      current = [data[0], data[1]];
      break;
    case 'C': {
      const [x1, y1, x2, y2, x, y] = data;
      // _bezierTo
      const ros = [svgOpts.maxRandomnessOffset || 1, (svgOpts.maxRandomnessOffset || 1) + 0.3];
      for (let i = 0; i < 2; i++) {
        if (i === 0) {
          svgOps.push({ op: 'move', data: [current[0], current[1]] });
        } else {
          svgOps.push({ op: 'move', data: [current[0] + _offsetOpt(ros[0], svgOpts), current[1] + _offsetOpt(ros[0], svgOpts)] });
        }
        const f = [x + _offsetOpt(ros[i], svgOpts), y + _offsetOpt(ros[i], svgOpts)];
        svgOps.push({ op: 'bcurveTo', data: [
          x1 + _offsetOpt(ros[i], svgOpts), y1 + _offsetOpt(ros[i], svgOpts),
          x2 + _offsetOpt(ros[i], svgOpts), y2 + _offsetOpt(ros[i], svgOpts),
          f[0], f[1],
        ]});
      }
      current = [x, y];
      break;
    }
    case 'Z':
      svgOps.push(..._doubleLine(current[0], current[1], first[0], first[1], svgOpts));
      current = [first[0], first[1]];
      break;
  }
}
result.svg_path = {
  input: "M 10 80 C 40 10, 65 10, 95 80",
  ops: svgOps,
};

console.log(JSON.stringify(result, null, 2));
