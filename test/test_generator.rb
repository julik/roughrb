# frozen_string_literal: true

require_relative "test_helper"

class TestGenerator < Minitest::Test
  def setup
    @gen = Rough::Generator.new
    @fixtures = JSON.parse(File.read(File.join(__dir__, "fixtures", "renderer.json")))
  end

  def test_line_returns_drawable
    d = @gen.line(0, 0, 100, 100, seed: 42)
    assert_kind_of Rough::Drawable, d
    assert_equal "line", d.shape
    assert_equal 1, d.sets.length
    assert_equal :path, d.sets[0].type
  end

  def test_line_matches_js_fixture
    d = @gen.line(0, 0, 100, 100, seed: 42)
    expected = @fixtures["line"]["ops"]
    assert_ops_match(expected, d.sets[0].ops, "line")
  end

  def test_rectangle_returns_drawable
    d = @gen.rectangle(10, 10, 200, 100, seed: 42)
    assert_equal "rectangle", d.shape
    assert_equal 1, d.sets.length # stroke only, no fill
  end

  def test_rectangle_stroke_matches_js
    d = @gen.rectangle(10, 10, 200, 100, seed: 42)
    expected = @fixtures["rectangle"]["ops"]
    assert_ops_match(expected, d.sets[0].ops, "rectangle")
  end

  def test_rectangle_with_fill
    d = @gen.rectangle(10, 10, 200, 100, seed: 42, fill: "red")
    assert_equal 2, d.sets.length # fill + stroke
  end

  def test_rectangle_with_solid_fill
    d = @gen.rectangle(10, 10, 200, 100, seed: 42, fill: "red", fill_style: "solid")
    assert_equal 2, d.sets.length
    assert_equal :fillPath, d.sets[0].type
    assert_equal :path, d.sets[1].type
  end

  def test_ellipse_returns_drawable
    d = @gen.ellipse(100, 100, 150, 100, seed: 42)
    assert_equal "ellipse", d.shape
    refute_empty d.sets
  end

  def test_circle_returns_drawable
    d = @gen.circle(100, 100, 80, seed: 42)
    assert_equal "circle", d.shape
  end

  def test_polygon_returns_drawable
    d = @gen.polygon([[0, 0], [100, 0], [100, 100], [0, 100]], seed: 42)
    assert_equal "polygon", d.shape
  end

  def test_linear_path_returns_drawable
    d = @gen.linear_path([[0, 0], [50, 50], [100, 0]], seed: 42)
    assert_equal "linearPath", d.shape
  end

  def test_arc_returns_drawable
    d = @gen.arc(100, 100, 200, 150, 0, Math::PI, seed: 42)
    assert_equal "arc", d.shape
  end

  def test_curve_returns_drawable
    d = @gen.curve([[0, 0], [50, 100], [100, 50], [150, 100]], seed: 42)
    assert_equal "curve", d.shape
  end

  def test_path_returns_drawable
    d = @gen.path("M 10 80 C 40 10, 65 10, 95 80", seed: 42)
    assert_equal "path", d.shape
    refute_empty d.sets
  end

  def test_ops_to_path
    d = @gen.line(0, 0, 100, 0, seed: 42)
    path_str = @gen.ops_to_path(d.sets[0])
    assert path_str.start_with?("M"), "Should start with M command"
    assert path_str.include?("C"), "Should contain C (bezier) command"
  end

  def test_ops_to_path_with_fixed_decimals
    d = @gen.line(0, 0, 100, 0, seed: 42)
    path_str = @gen.ops_to_path(d.sets[0], 2)
    # All numbers should have at most 2 decimal places
    numbers = path_str.scan(/[-+]?\d+\.?\d*/)
    numbers.each do |n|
      if n.include?(".")
        decimals = n.split(".")[1].length
        assert decimals <= 2, "Expected at most 2 decimals, got #{decimals} in '#{n}'"
      end
    end
  end

  def test_to_paths
    d = @gen.rectangle(10, 10, 100, 50, seed: 42)
    paths = @gen.to_paths(d)
    assert_equal 1, paths.length
    pi = paths[0]
    assert_kind_of Rough::PathInfo, pi
    assert_equal "#000", pi.stroke
    assert_equal 1, pi.stroke_width
    assert_equal "none", pi.fill
    refute_empty pi.d
  end

  def test_to_paths_with_fill
    d = @gen.rectangle(10, 10, 100, 50, seed: 42, fill: "red")
    paths = @gen.to_paths(d)
    assert_equal 2, paths.length
    # First is fill sketch
    assert_equal "red", paths[0].stroke
    assert_equal "none", paths[0].fill
    # Second is stroke
    assert_equal "#000", paths[1].stroke
  end

  def test_deterministic_with_seed
    d1 = @gen.line(0, 0, 100, 100, seed: 42)
    d2 = @gen.line(0, 0, 100, 100, seed: 42)
    p1 = @gen.ops_to_path(d1.sets[0])
    p2 = @gen.ops_to_path(d2.sets[0])
    assert_equal p1, p2, "Same seed should produce identical output"
  end

  def test_different_seeds_differ
    d1 = @gen.line(0, 0, 100, 100, seed: 42)
    d2 = @gen.line(0, 0, 100, 100, seed: 99)
    p1 = @gen.ops_to_path(d1.sets[0])
    p2 = @gen.ops_to_path(d2.sets[0])
    refute_equal p1, p2, "Different seeds should produce different output"
  end

  private

  def assert_ops_match(expected_ops, actual_ops, label)
    assert_equal expected_ops.length, actual_ops.length,
      "#{label}: op count mismatch"
    expected_ops.each_with_index do |exp_op, i|
      actual = actual_ops[i]
      assert_equal exp_op["op"], actual.op.to_s, "#{label}: op type at #{i}"
      exp_op["data"].each_with_index do |val, j|
        assert_in_delta val, actual.data[j], 1e-10, "#{label}: data[#{j}] at op #{i}"
      end
    end
  end
end
