# frozen_string_literal: true

require_relative "test_helper"
require "rough/points_on_curve"

class TestPointsOnCurve < Minitest::Test
  def setup
    @fixtures = JSON.parse(File.read(File.join(__dir__, "fixtures", "points_and_hachure.json")))
  end

  def test_curve_to_bezier_matches_js
    @fixtures["curve_to_bezier"].each_with_index do |fixture, fi|
      input = fixture["input"]
      expected = fixture["output"]
      actual = Rough::PointsOnCurve.curve_to_bezier(input)
      assert_equal expected.length, actual.length, "Point count mismatch for fixture #{fi}"
      expected.each_with_index do |exp_pt, i|
        assert_in_delta exp_pt[0], actual[i][0], 1e-10, "X mismatch at #{i} for fixture #{fi}"
        assert_in_delta exp_pt[1], actual[i][1], 1e-10, "Y mismatch at #{i} for fixture #{fi}"
      end
    end
  end

  def test_points_on_bezier_curves_matches_js
    @fixtures["points_on_bezier_curves"].each_with_index do |fixture, fi|
      input = fixture["input"]

      [["tolerance_0_15", 0.15, nil], ["tolerance_10", 10, nil], ["with_distance", 0.15, 2]].each do |key, tol, dist|
        expected = fixture[key]
        actual = Rough::PointsOnCurve.points_on_bezier_curves(input, tol, dist)
        assert_equal expected.length, actual.length, "Point count mismatch for #{key} fixture #{fi}"
        expected.each_with_index do |exp_pt, i|
          assert_in_delta exp_pt[0], actual[i][0], 1e-10, "X mismatch at #{i} for #{key} fixture #{fi}"
          assert_in_delta exp_pt[1], actual[i][1], 1e-10, "Y mismatch at #{i} for #{key} fixture #{fi}"
        end
      end
    end
  end

  def test_curve_to_bezier_requires_three_points
    assert_raises(RuntimeError) { Rough::PointsOnCurve.curve_to_bezier([[0, 0], [1, 1]]) }
  end
end
