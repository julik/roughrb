// Generate reference outputs for PointsOnCurve, HachureFill, PointsOnPath
import { pointsOnBezierCurves } from '../../tmp/rough/node_modules/points-on-curve/lib/index.js';
import { curveToBezier } from '../../tmp/rough/node_modules/points-on-curve/lib/curve-to-bezier.js';
import { hachureLines } from '../../tmp/rough/node_modules/hachure-fill/bin/hachure.js';
import { pointsOnPath } from '../../tmp/rough/node_modules/points-on-path/lib/index.js';

const result = {};

// PointsOnCurve: curveToBezier
const curveInputs = [
  [[0,0], [50,100], [100,0]],
  [[0,0], [25,50], [75,50], [100,0]],
  [[0,0], [20,80], [50,100], [80,80], [100,0]],
];
result.curve_to_bezier = curveInputs.map(pts => ({
  input: pts,
  output: curveToBezier(pts),
}));

// PointsOnCurve: pointsOnBezierCurves
const bezierInputs = [
  [[0,0], [25,100], [75,100], [100,0]],
  [[0,0], [0,100], [100,100], [100,0], [200,0], [300,100], [300,0]],
];
result.points_on_bezier_curves = bezierInputs.map(pts => ({
  input: pts,
  tolerance_0_15: pointsOnBezierCurves(pts, 0.15),
  tolerance_10: pointsOnBezierCurves(pts, 10),
  with_distance: pointsOnBezierCurves(pts, 0.15, 2),
}));

// HachureFill — fresh copies for each call since hachureLines mutates input
function freshRect() { return [[0,0], [100,0], [100,100], [0,100]]; }
function freshTri() { return [[0,0], [50,100], [100,0]]; }
result.hachure_lines = [
  { input: [freshRect()], gap: 10, angle: 0, skip: 1, output: hachureLines([freshRect()], 10, 0, 1) },
  { input: [freshRect()], gap: 10, angle: 45, skip: 1, output: hachureLines([freshRect()], 10, 45, 1) },
  { input: [freshRect()], gap: 10, angle: -41, skip: 1, output: hachureLines([freshRect()], 10, -41, 1) },
  { input: [freshTri()], gap: 8, angle: 0, skip: 1, output: hachureLines([freshTri()], 8, 0, 1) },
  { input: [freshRect()], gap: 10, angle: 0, skip: 10, output: hachureLines([freshRect()], 10, 0, 10) },
];

// PointsOnPath
const pathInputs = [
  "M 0 0 L 100 0 L 100 100 L 0 100 Z",
  "M 10 80 Q 52.5 10 95 80",
  "M 10 80 C 40 10 65 10 95 80",
];
result.points_on_path = pathInputs.map(d => ({
  input: d,
  output: pointsOnPath(d, 0.15, 0),
  with_distance: pointsOnPath(d, 0.15, 2),
}));

console.log(JSON.stringify(result, null, 2));
