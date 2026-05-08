# frozen_string_literal: true

require_relative "test_helper"

# Verifies that, when a seed is supplied, roughrb produces output that is
# byte-identical (within float tolerance) to roughjs for the shapes used in
# the regression-example scene under tmp/regression-example.
#
# Fixture is generated from roughjs by:
#   node tmp/regression-example/js/gen_regression_fixture.mjs \
#        > test/fixtures/parity_regression.json
#
# The fixture covers the shape mix the user reported as diverging:
# stroked circles, solid-fill circles, cross-hatch fills, linear paths,
# lines, curves, svg paths, arcs and polygons.
class TestParityRegression < Minitest::Test
  FIXTURE = JSON.parse(File.read(File.join(__dir__, "fixtures", "parity_regression.json")))
  CASES = FIXTURE["cases"].each_with_object({}) { |c, h| h[c["label"]] = c }

  def gen
    @gen ||= Rough::Generator.new
  end

  def test_circle_outline_matches_roughjs
    drawable = gen.circle(700, 450, 720,
      seed: 1, stroke: "#1f2430", stroke_width: 3, roughness: 0.5, bowing: 0.8)
    assert_drawable_matches "circle_outline", drawable
  end

  def test_line_matches_roughjs
    drawable = gen.line(409.94, 661.03, 488.84, 158.41,
      seed: 2, stroke: "#1f2430", stroke_width: 3, roughness: 0.8, bowing: 0.3)
    assert_drawable_matches "line", drawable
  end

  def test_solid_filled_circle_matches_roughjs
    drawable = gen.circle(700, 450, 10,
      seed: 3, stroke: "#1f2430", stroke_width: 2, roughness: 1, bowing: 1.6,
      fill: "#1f2430", fill_style: "solid")
    assert_drawable_matches "circle_solid_fill", drawable
  end

  def test_cross_hatch_filled_circle_matches_roughjs
    drawable = gen.circle(580, 305, 200,
      seed: 4, stroke: "#1f2430", stroke_width: 2, roughness: 1, bowing: 1.6,
      fill: "#c8553d", fill_style: "cross-hatch")
    assert_drawable_matches "circle_cross_hatch", drawable
  end

  def test_linear_path_arrow_matches_roughjs
    points = [
      [700, 450], [714, 456], [730, 451], [718, 478],
      [746, 468], [744, 428], [774, 414], [752, 368]
    ]
    drawable = gen.linear_path(points,
      seed: 5, stroke: "#1f2430", stroke_width: 3, roughness: 1, bowing: 0.2)
    assert_drawable_matches "linear_path_arrow", drawable
  end

  def test_rectangle_with_hachure_matches_roughjs
    drawable = gen.rectangle(0, 0, 100, 100, seed: 7, fill: "blue", fill_style: "hachure")
    assert_drawable_matches "rect_hachure", drawable
  end

  def test_rectangle_with_zigzag_matches_roughjs
    drawable = gen.rectangle(0, 0, 100, 100, seed: 7, fill: "blue", fill_style: "zigzag")
    assert_drawable_matches "rect_zigzag", drawable
  end

  def test_rectangle_with_dashed_matches_roughjs
    drawable = gen.rectangle(0, 0, 100, 100, seed: 7, fill: "blue", fill_style: "dashed")
    assert_drawable_matches "rect_dashed", drawable
  end

  def test_curve_matches_roughjs
    drawable = gen.curve(
      [[0, 0], [50, 30], [100, 0], [150, 40], [200, 0]],
      seed: 8, stroke: "#000", stroke_width: 2, roughness: 1.5
    )
    assert_drawable_matches "curve", drawable
  end

  def test_svg_path_matches_roughjs
    drawable = gen.path("M10 80 C 40 10, 65 10, 95 80 S 150 150, 180 80", seed: 9)
    assert_drawable_matches "svg_path", drawable
  end

  def test_arc_open_matches_roughjs
    drawable = gen.arc(100, 100, 200, 160, 0, Math::PI, closed: false, seed: 10)
    assert_drawable_matches "arc_open", drawable
  end

  def test_arc_filled_matches_roughjs
    drawable = gen.arc(100, 100, 200, 160, 0, Math::PI, closed: true,
      seed: 10, fill: "red", fill_style: "hachure")
    assert_drawable_matches "arc_filled", drawable
  end

  def test_polygon_cross_hatch_matches_roughjs
    drawable = gen.polygon(
      [[0, 0], [100, 0], [100, 100], [0, 100]],
      seed: 11, fill: "red", fill_style: "cross-hatch"
    )
    assert_drawable_matches "polygon_cross_hatch", drawable
  end

  def test_preserve_vertices_matches_roughjs
    drawable = gen.line(0, 0, 100, 0, seed: 12, preserve_vertices: true)
    assert_drawable_matches "line_preserve_vertices", drawable
  end

  def test_disable_multi_stroke_matches_roughjs
    drawable = gen.line(0, 0, 100, 0, seed: 12, disable_multi_stroke: true)
    assert_drawable_matches "line_no_multi_stroke", drawable
  end

  # Documents an INTENTIONAL deviation from roughjs upstream.
  #
  # roughjs's fillers/dot-filler.js calls Math.random() unconditionally,
  # bypassing the seeded randomizer, so dot fills are non-deterministic
  # there even when a seed is supplied. roughrb deliberately diverges and
  # routes dot positions through the seeded randomizer (see
  # lib/rough/fillers/dot.rb) so that seeded users get reproducible output.
  #
  # When seed is 0 (unset) the seeded randomizer falls through to
  # Kernel#rand, matching roughjs's stochastic behaviour for unseeded use.
  def test_dots_filler_is_deterministic_when_seeded
    a = gen.rectangle(0, 0, 100, 100, seed: 42, fill: "red", fill_style: "dots")
    b = gen.rectangle(0, 0, 100, 100, seed: 42, fill: "red", fill_style: "dots")

    assert_equal flatten_data(a), flatten_data(b),
      "two seeded dot fills with the same seed must produce identical output"
  end

  def test_dots_filler_is_random_when_unseeded
    srand(1)
    a = gen.rectangle(0, 0, 100, 100, fill: "red", fill_style: "dots")
    srand(2)
    b = gen.rectangle(0, 0, 100, 100, fill: "red", fill_style: "dots")

    a_data = flatten_data(a)
    b_data = flatten_data(b)

    assert_equal a_data.length, b_data.length, "structure should be stable"
    refute_equal a_data, b_data,
      "unseeded dot fills should fall through to Kernel#rand"
  end

  private

  def assert_drawable_matches(label, drawable)
    expected = CASES.fetch(label) { flunk("no fixture for #{label}") }
    assert_equal expected["sets"].length, drawable.sets.length, "#{label}: set count"

    drawable.sets.each_with_index do |actual_set, set_idx|
      expected_set = expected["sets"][set_idx]
      assert_equal expected_set["type"], actual_set.type.to_s,
        "#{label}: set[#{set_idx}] type mismatch"

      assert_equal expected_set["ops"].length, actual_set.ops.length,
        "#{label}: set[#{set_idx}] op count (expected #{expected_set["ops"].length}, got #{actual_set.ops.length})"

      expected_set["ops"].each_with_index do |exp_op, op_idx|
        actual_op = actual_set.ops[op_idx]
        assert_equal exp_op["op"], actual_op.op.to_s,
          "#{label}: set[#{set_idx}].ops[#{op_idx}] op type"
        assert_equal exp_op["data"].length, actual_op.data.length,
          "#{label}: set[#{set_idx}].ops[#{op_idx}] data length"
        exp_op["data"].each_with_index do |val, j|
          assert_in_delta val, actual_op.data[j], 1e-9,
            "#{label}: set[#{set_idx}].ops[#{op_idx}].data[#{j}]"
        end
      end
    end
  end

  def flatten_data(drawable)
    drawable.sets.flat_map { |s| s.ops.flat_map(&:data) }
  end
end
