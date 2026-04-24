# Plan: Port rough.js to Ruby (SVG-only)

## Context
Port the rough.js hand-drawn graphics library to Ruby as the `roughrb` gem. Only SVG output (no Canvas). All external JS deps will be reimplemented inline. Tests first (minitest), plain string SVG output, zero runtime dependencies.

## Architecture Overview

The JS lib has this pipeline:
```
User calls shape method → Generator resolves options → Renderer produces OpSets (move/lineTo/bcurveTo) → SVG serializer converts to <path> elements
```

We'll mirror this in Ruby with these modules/classes under `Rough`:

```
lib/
  rough.rb                    # top-level require, module Rough
  rough/
    version.rb
    random.rb                 # Seeded PRNG (Park-Miller LCG)
    geometry.rb               # Point = [x,y], Line, lineLength, etc.
    options.rb                # Options struct + ResolvedOptions with defaults
    op.rb                     # Op, OpSet, Drawable, PathInfo structs
    renderer.rb               # Core rough rendering (lines, curves, ellipses, arcs, SVG paths)
    generator.rb              # RoughGenerator - main API, composes stroke+fill into Drawables
    svg.rb                    # SVG string serializer (Drawable → SVG string fragments)
    path_data_parser.rb       # SVG path string parser (port of path-data-parser)
    points_on_curve.rb        # Bezier point sampling (port of points-on-curve)
    points_on_path.rb         # SVG path point sampling (port of points-on-path)
    hachure_fill.rb           # Scan-line hachure algorithm (port of hachure-fill)
    fillers/
      base.rb                 # PatternFiller interface + RenderHelper
      hachure.rb              # Default parallel-line fill
      hatch.rb                # Cross-hatch (extends hachure)
      zigzag.rb               # Zigzag fill
      zigzag_line.rb          # Zigzag-line fill
      dashed.rb               # Dashed fill
      dot.rb                  # Dot fill
      registry.rb             # getFiller factory
```

## Implementation Order (test-first, bottom-up)

### Step 1: Project scaffolding
- Create gem structure: Gemfile, roughrb.gemspec, lib/rough.rb, test/test_helper.rb
- Rakefile with minitest default task

### Step 2: `Rough::Random` (port of math.ts)
- Park-Miller LCG: `seed = (48271 * seed) % (2^31 - 1)`
- `Random.new(seed)` with `#next` returning float in [0,1)
- `Random.new_seed` class method
- **Tests:** deterministic sequences for known seeds, range checks

### Step 3: `Rough::Geometry` (port of geometry.ts)
- `Point = [Numeric, Numeric]` (just arrays)
- `line_length(p1, p2)` — Euclidean distance
- **Tests:** known distances

### Step 4: `Rough::Options` / `Rough::Op` (port of core.ts types)
- `Options` as a data class / Struct with all 28 fields
- `ResolvedOptions` with defaults filled in (roughness=1, bowing=1, stroke='#000', hachureAngle=-41, fillStyle='hachure', etc.)
- `Op = Struct.new(:op, :data)`, `OpSet = Struct.new(:type, :ops, :size, :path)`
- `Drawable = Struct.new(:shape, :options, :sets)`
- `PathInfo = Struct.new(:d, :stroke, :stroke_width, :fill)`
- **Tests:** default resolution, merging user options

### Step 5: `Rough::PathDataParser` (port of path-data-parser)
- `parse(d)` → array of `{key:, data:}` segments
- `absolutize(segments)` → convert relative commands to absolute
- `normalize(segments)` → reduce to M, L, C, Z only
- **Tests:** parse known SVG paths, round-trip serialize, normalize curves

### Step 6: `Rough::PointsOnCurve` (port of points-on-curve)
- `points_on_bezier_curves(points, tolerance, distance)` → sampled points
- `curve_to_bezier(points)` → Catmull-Rom to cubic Bezier conversion
- **Tests:** known curve inputs, point count/range checks

### Step 7: `Rough::HachureFill` (port of hachure-fill)
- `hachure_lines(polygon_list, gap, angle, skip_offset)` → array of lines
- Scan-line intersection algorithm with rotation
- **Tests:** simple rectangle hachure, triangle, known line counts

### Step 8: `Rough::PointsOnPath` (port of points-on-path)
- `points_on_path(path_string, tolerance, distance)` → array of point arrays
- Combines PathDataParser + PointsOnCurve
- **Tests:** simple paths, multi-segment paths

### Step 9: `Rough::Renderer` (port of renderer.ts)
- Core rough-line algorithm: Bezier with random displacement
- Double-stroke effect
- `line`, `linear_path`, `polygon`, `rectangle`, `curve`, `ellipse`, `arc`, `svg_path`
- `solid_fill_polygon`, `pattern_fill_polygons`, `pattern_fill_arc`
- **Tests:** deterministic output with fixed seed, op counts, op types

### Step 10: Fillers (port of fillers/)
- `Rough::Fillers::Base` with `RenderHelper` module
- `Hachure`, `Hatch`, `Zigzag`, `ZigzagLine`, `Dashed`, `Dot`
- `Rough::Fillers.get(fill_style, helper)` factory
- **Tests:** each filler produces non-empty OpSets for a simple polygon

### Step 11: `Rough::Generator` (port of generator.ts)
- Main API: `line`, `rectangle`, `ellipse`, `circle`, `polygon`, `arc`, `curve`, `path`, `linear_path`
- `ops_to_path(opset)` → SVG path d string
- `to_paths(drawable)` → array of PathInfo
- **Tests:** each shape method returns valid Drawable, deterministic with seed

### Step 12: `Rough::SVG` (port of svg.ts — string-based)
- `draw(drawable)` → SVG `<g>` string containing `<path>` elements
- Handles stroke, fill, fillSketch op set types
- Sets stroke-dasharray, fill-rule="evenodd", etc.
- Helper: `Rough.svg_document(width, height) { |svg| ... }` for complete SVG wrapper
- **Tests:** output contains valid SVG markup, correct attributes, visual regression via saved SVG fixtures

## Key Porting Decisions

1. **No DOM** — SVG output is string concatenation, XML-escaped where needed
2. **`Math.imul` equivalent** — Ruby integers are arbitrary precision, so `(a * b) & 0xFFFFFFFF` for 32-bit multiply, but Park-Miller only needs modular arithmetic which Ruby handles natively
3. **Points are plain `[x, y]` arrays** — no wrapper class needed
4. **Options use keyword arguments** — `generator.rectangle(10, 20, 100, 50, roughness: 2, fill: 'red')`
5. **Seed determinism** — critical for testing; all tests use fixed seeds

## Cross-language test strategy

The JS library has **no automated tests** — only visual HTML test pages. The external deps
(hachure-fill, path-data-parser, points-on-curve, points-on-path) also have zero test suites.

To ensure correctness we will **generate reference data from the JS code** and copy it verbatim
into Ruby minitest assertions. For every ported module:

1. **Write a small Node script** (`test/fixtures/generate_<module>.mjs`) that calls the JS function
   with known inputs and prints the outputs as JSON.
2. **Capture that JSON** into `test/fixtures/<module>.json`.
3. **Write the Ruby test** that loads the fixture and asserts the Ruby output matches exactly
   (or within a small float epsilon for geometry/curve math).

This gives us **cross-language golden tests** — the JS output is the ground truth.

### Modules and their reference fixtures

| Module | JS function(s) to snapshot | Fixture inputs |
|--------|---------------------------|----------------|
| `Random` | `new Random(seed).next()` × N | seeds: 42, 12345, 1 — 20 values each |
| `PathDataParser` | `parsePath`, `absolutize`, `normalize` | 5-6 SVG path strings (simple line, quad bezier, arc, relative commands, compound path) |
| `PointsOnCurve` | `pointsOnBezierCurves`, `curveToBezier` | 3-4 sets of control points |
| `HachureFill` | `hachureLines(polygonList, gap, angle, skipOffset)` | rectangle, triangle, concave polygon at various angles/gaps |
| `PointsOnPath` | `pointsOnPath(d, tolerance, distance)` | 3-4 SVG path strings |
| `Renderer` | `line`, `rectangle`, `ellipse`, `polygon`, `curve`, `arc`, `svgPath` | each shape with fixed seed, default options |
| `Fillers` | each filler's `fillPolygons` | unit square polygon, fixed seed, for each fill style |
| `Generator` | `toPaths(generator.rectangle(...))` etc. | each shape method with fixed seed |
| `SVG` | full SVG string output | a few shapes composed together |

### Visual regression (end-to-end)

Additionally, for final validation:
- Generate SVGs from both JS and Ruby using **identical seeds and options**
- Store the JS SVGs in `test/fixtures/visual/` as reference
- Ruby tests generate SVGs and compare strings (or diff path `d` attributes)
- This catches any subtle drift in the rendering pipeline

## Verification
- `bundle exec rake test` runs full minitest suite
- `node test/fixtures/generate_all.mjs` regenerates all JSON fixtures from JS source
- Each layer testable independently (Random, PathDataParser, PointsOnCurve, HachureFill, Renderer, Generator, SVG)

## Key JS Source Files Reference
- `tmp/rough/src/math.ts` — PRNG
- `tmp/rough/src/geometry.ts` — Point/Line types
- `tmp/rough/src/core.ts` — Options, Op, OpSet, Drawable types
- `tmp/rough/src/renderer.ts` — Core rendering engine (~400 lines)
- `tmp/rough/src/generator.ts` — Generator API (~250 lines)
- `tmp/rough/src/svg.ts` — SVG DOM output (~100 lines)
- `tmp/rough/src/fillers/` — All 6 fill patterns + scan-line hachure
- External deps (in node_modules): `hachure-fill`, `path-data-parser`, `points-on-curve`, `points-on-path`
