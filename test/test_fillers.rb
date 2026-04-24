# frozen_string_literal: true

require_relative "test_helper"
require "rough/renderer"
require "rough/fillers/registry"

class TestFillers < Minitest::Test
  def setup
    @helper = Rough::Renderer.helper
    @polygon = [[0, 0], [100, 0], [100, 100], [0, 100]]
  end

  def test_hachure_filler
    o = Rough::ResolvedOptions.new(seed: 42, fill_style: "hachure")
    filler = Rough::Fillers.get(o, @helper)
    result = filler.fill_polygons([@polygon], o)
    assert_equal :fillSketch, result.type
    refute_empty result.ops, "Hachure should produce ops"
  end

  def test_hatch_filler
    o = Rough::ResolvedOptions.new(seed: 42, fill_style: "cross-hatch")
    filler = Rough::Fillers.get(o, @helper)
    result = filler.fill_polygons([@polygon], o)
    assert_equal :fillSketch, result.type
    refute_empty result.ops
  end

  def test_zigzag_filler
    o = Rough::ResolvedOptions.new(seed: 42, fill_style: "zigzag")
    filler = Rough::Fillers.get(o, @helper)
    result = filler.fill_polygons([@polygon], o)
    assert_equal :fillSketch, result.type
    refute_empty result.ops
  end

  def test_zigzag_line_filler
    o = Rough::ResolvedOptions.new(seed: 42, fill_style: "zigzag-line")
    filler = Rough::Fillers.get(o, @helper)
    result = filler.fill_polygons([@polygon], o)
    assert_equal :fillSketch, result.type
    refute_empty result.ops
  end

  def test_dashed_filler
    o = Rough::ResolvedOptions.new(seed: 42, fill_style: "dashed")
    filler = Rough::Fillers.get(o, @helper)
    result = filler.fill_polygons([@polygon], o)
    assert_equal :fillSketch, result.type
    refute_empty result.ops
  end

  def test_dot_filler
    o = Rough::ResolvedOptions.new(seed: 42, fill_style: "dots")
    filler = Rough::Fillers.get(o, @helper)
    result = filler.fill_polygons([@polygon], o)
    assert_equal :fillSketch, result.type
    refute_empty result.ops
  end

  def test_registry_returns_correct_fillers
    %w[hachure cross-hatch zigzag zigzag-line dashed dots].each do |style|
      o = Rough::ResolvedOptions.new(fill_style: style)
      filler = Rough::Fillers.get(o, @helper)
      refute_nil filler, "Should return a filler for '#{style}'"
    end
  end

  def test_unknown_fill_style_defaults_to_hachure
    o = Rough::ResolvedOptions.new(fill_style: "nonexistent")
    filler = Rough::Fillers.get(o, @helper)
    assert_kind_of Rough::Fillers::Hachure, filler
  end

  def test_cross_hatch_produces_more_ops_than_hachure
    o_hachure = Rough::ResolvedOptions.new(seed: 42, fill_style: "hachure")
    o_hatch = Rough::ResolvedOptions.new(seed: 42, fill_style: "cross-hatch")
    h_result = Rough::Fillers.get(o_hachure, @helper).fill_polygons([@polygon], o_hachure)
    x_result = Rough::Fillers.get(o_hatch, @helper).fill_polygons([@polygon], o_hatch)
    assert x_result.ops.length > h_result.ops.length,
      "Cross-hatch should produce more ops than hachure"
  end
end
