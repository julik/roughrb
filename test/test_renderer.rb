# frozen_string_literal: true

require_relative "test_helper"
require "rough/renderer"

class TestRenderer < Minitest::Test
  def setup
    @fixtures = JSON.parse(File.read(File.join(__dir__, "fixtures", "renderer.json")))
  end

  def test_line_matches_js
    fixture = @fixtures["line"]
    o = Rough::ResolvedOptions.new(seed: 42)
    result = Rough::Renderer.line(0, 0, 100, 100, o)
    assert_ops_match(fixture["ops"], result.ops, "line")
  end

  def test_rectangle_matches_js
    fixture = @fixtures["rectangle"]
    o = Rough::ResolvedOptions.new(seed: 42)
    result = Rough::Renderer.rectangle(10, 10, 200, 100, o)
    assert_ops_match(fixture["ops"], result.ops, "rectangle")
  end

  def test_ellipse_matches_js
    fixture = @fixtures["ellipse"]
    o = Rough::ResolvedOptions.new(seed: 42)
    result = Rough::Renderer.ellipse(100, 100, 150, 100, o)
    assert_ops_match(fixture["ops"], result.ops, "ellipse")
  end

  def test_svg_path_matches_js
    fixture = @fixtures["svg_path"]
    o = Rough::ResolvedOptions.new(seed: 42)
    result = Rough::Renderer.svg_path("M 10 80 C 40 10, 65 10, 95 80", o)
    assert_ops_match(fixture["ops"], result.ops, "svg_path")
  end

  def test_line_returns_opset
    o = Rough::ResolvedOptions.new(seed: 1)
    result = Rough::Renderer.line(0, 0, 50, 50, o)
    assert_kind_of Rough::OpSet, result
    assert_equal :path, result.type
    refute_empty result.ops
  end

  def test_double_stroke_produces_more_ops
    single = Rough::ResolvedOptions.new(seed: 1, disable_multi_stroke: true)
    double = Rough::ResolvedOptions.new(seed: 1, disable_multi_stroke: false)
    r1 = Rough::Renderer.line(0, 0, 100, 0, single)
    r2 = Rough::Renderer.line(0, 0, 100, 0, double)
    assert r2.ops.length > r1.ops.length, "Double stroke should produce more ops"
  end

  def test_solid_fill_polygon
    o = Rough::ResolvedOptions.new(seed: 1)
    points = [[0, 0], [100, 0], [100, 100], [0, 100]]
    result = Rough::Renderer.solid_fill_polygon([points], o)
    assert_equal :fillPath, result.type
    assert result.ops.length >= 4
    assert_equal :move, result.ops[0].op
  end

  private

  def assert_ops_match(expected_ops, actual_ops, label)
    assert_equal expected_ops.length, actual_ops.length,
      "#{label}: op count mismatch (expected #{expected_ops.length}, got #{actual_ops.length})"
    expected_ops.each_with_index do |exp_op, i|
      actual = actual_ops[i]
      assert_equal exp_op["op"], actual.op.to_s, "#{label}: op type mismatch at #{i}"
      assert_equal exp_op["data"].length, actual.data.length, "#{label}: data length mismatch at op #{i}"
      exp_op["data"].each_with_index do |val, j|
        assert_in_delta val, actual.data[j], 1e-10, "#{label}: data[#{j}] mismatch at op #{i}"
      end
    end
  end
end
