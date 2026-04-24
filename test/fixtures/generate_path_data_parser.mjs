// Generate reference outputs for PathDataParser
// Run: node test/fixtures/generate_path_data_parser.mjs > test/fixtures/path_data_parser.json
import { parsePath, absolutize, normalize, serialize } from '../../tmp/rough/node_modules/path-data-parser/lib/index.js';

const testPaths = [
  "M 10 80 L 100 80",
  "M 10 80 Q 52.5 10 95 80",
  "M 10 80 C 40 10, 65 10, 95 80",
  "m 10 80 l 90 0 l 0 -70 z",
  "M 80 80 A 45 45 0 0 0 125 125",
  "M 0 0 L 100 0 L 100 100 L 0 100 Z",
  "M 10 10 h 80 v 80 h -80 Z",
  "M 10 80 Q 95 10 180 80 T 350 80",
  "M 10 80 C 40 10, 65 10, 95 80 S 150 150, 180 80",
];

const result = {};
for (const d of testPaths) {
  const parsed = parsePath(d);
  const abs = absolutize(parsed);
  const norm = normalize(abs);
  const ser = serialize(parsed);
  result[d] = { parsed, absolutized: abs, normalized: norm, serialized: ser };
}

console.log(JSON.stringify(result, null, 2));
