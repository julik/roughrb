# frozen_string_literal: true

require_relative "test_helper"
require "rough/options"

class TestOptions < Minitest::Test
  def test_defaults
    opts = Rough::ResolvedOptions.new
    assert_equal 2, opts.max_randomness_offset
    assert_equal 1, opts.roughness
    assert_equal 1, opts.bowing
    assert_equal "#000", opts.stroke
    assert_equal 1, opts.stroke_width
    assert_equal 0, opts.curve_tightness
    assert_in_delta 0.95, opts.curve_fitting
    assert_equal 9, opts.curve_step_count
    assert_nil opts.fill
    assert_equal "hachure", opts.fill_style
    assert_equal(-1, opts.fill_weight)
    assert_equal(-41, opts.hachure_angle)
    assert_equal(-1, opts.hachure_gap)
    assert_equal(-1, opts.dash_offset)
    assert_equal(-1, opts.dash_gap)
    assert_equal(-1, opts.zigzag_offset)
    assert_equal 0, opts.seed
    assert_equal false, opts.disable_multi_stroke
    assert_equal false, opts.disable_multi_stroke_fill
    assert_equal false, opts.preserve_vertices
    assert_in_delta 0.8, opts.fill_shape_roughness_gain
  end

  def test_override
    opts = Rough::ResolvedOptions.new(roughness: 3, fill: "red")
    assert_equal 3, opts.roughness
    assert_equal "red", opts.fill
    assert_equal "#000", opts.stroke # unchanged
  end

  def test_merge
    opts = Rough::ResolvedOptions.new(roughness: 2)
    merged = opts.merge(bowing: 5, fill: "blue")
    assert_equal 5, merged.bowing
    assert_equal "blue", merged.fill
    assert_equal 2, merged.roughness # preserved
    # original unchanged
    assert_equal 1, opts.bowing
  end
end
