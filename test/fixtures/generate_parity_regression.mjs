// Generate reference fixture data for test_parity_regression.rb. Pairs each
// shape/option permutation roughrb's parity test exercises with the byte-exact
// output rough.js produces for the same seeded inputs.
//
// Usage (requires `roughjs@^4.6.6` installed in a sibling project — see
// tmp/regression-example/js for one):
//
//   cd tmp/regression-example/js && \
//     node ../../../test/fixtures/generate_parity_regression.mjs \
//       > ../../../test/fixtures/parity_regression.json
//
// Re-run when bumping the rough.js version under test or when adding new
// cases to test_parity_regression.rb.

import rough from 'roughjs/bundled/rough.esm.js';
const gen = rough.generator();

function flatten(label, drawable) {
  return {
    label,
    sets: drawable.sets.map(set => ({
      type: set.type,
      ops: set.ops.map(op => ({
        op: op.op,
        data: op.data
      }))
    }))
  };
}

const cases = [];

// Stroked circle (boundary)
cases.push(flatten("circle_outline", gen.circle(700, 450, 720, {
  seed: 1, stroke: '#1f2430', strokeWidth: 3, roughness: 0.5, bowing: 0.8
})));

// Line
cases.push(flatten("line", gen.line(409.94, 661.03, 488.84, 158.41, {
  seed: 2, stroke: '#1f2430', strokeWidth: 3, roughness: 0.8, bowing: 0.3
})));

// Solid-filled circle (center point)
cases.push(flatten("circle_solid_fill", gen.circle(700, 450, 10, {
  seed: 3, stroke: '#1f2430', strokeWidth: 2, roughness: 1, bowing: 1.6,
  fill: '#1f2430', fillStyle: 'solid'
})));

// Cross-hatch filled circle (target circle)
cases.push(flatten("circle_cross_hatch", gen.circle(580, 305, 200, {
  seed: 4, stroke: '#1f2430', strokeWidth: 2, roughness: 1, bowing: 1.6,
  fill: '#c8553d', fillStyle: 'cross-hatch'
})));

// Linear path (zig-zag arrow)
const arrowPoints = [
  [700, 450], [714, 456], [730, 451], [718, 478],
  [746, 468], [744, 428], [774, 414], [752, 368]
];
cases.push(flatten("linear_path_arrow", gen.linearPath(arrowPoints, {
  seed: 5, stroke: '#1f2430', strokeWidth: 3, roughness: 1, bowing: 0.2
})));

// Rectangle with hachure
cases.push(flatten("rect_hachure", gen.rectangle(0, 0, 100, 100, {
  seed: 7, fill: 'blue', fillStyle: 'hachure'
})));

// Rectangle with zigzag fill
cases.push(flatten("rect_zigzag", gen.rectangle(0, 0, 100, 100, {
  seed: 7, fill: 'blue', fillStyle: 'zigzag'
})));

// Rectangle with dashed fill
cases.push(flatten("rect_dashed", gen.rectangle(0, 0, 100, 100, {
  seed: 7, fill: 'blue', fillStyle: 'dashed'
})));

// Curve
cases.push(flatten("curve", gen.curve(
  [[0,0],[50,30],[100,0],[150,40],[200,0]],
  { seed: 8, stroke: '#000', strokeWidth: 2, roughness: 1.5 }
)));

// Path with svg path commands
cases.push(flatten("svg_path", gen.path("M10 80 C 40 10, 65 10, 95 80 S 150 150, 180 80",
  { seed: 9 })));

// Arc
cases.push(flatten("arc_open", gen.arc(100, 100, 200, 160, 0, Math.PI, false, {
  seed: 10
})));

// Closed arc with fill
cases.push(flatten("arc_filled", gen.arc(100, 100, 200, 160, 0, Math.PI, true, {
  seed: 10, fill: 'red', fillStyle: 'hachure'
})));

// Polygon with cross-hatch
cases.push(flatten("polygon_cross_hatch", gen.polygon(
  [[0,0],[100,0],[100,100],[0,100]],
  { seed: 11, fill: 'red', fillStyle: 'cross-hatch' }
)));

// preserveVertices
cases.push(flatten("line_preserve_vertices", gen.line(0, 0, 100, 0, {
  seed: 12, preserveVertices: true
})));

// Disabled multi-stroke
cases.push(flatten("line_no_multi_stroke", gen.line(0, 0, 100, 0, {
  seed: 12, disableMultiStroke: true
})));

console.log(JSON.stringify({ cases }, null, 2));
