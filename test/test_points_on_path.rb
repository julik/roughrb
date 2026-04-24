require_relative "test_helper"
require "rough/points_on_path"

class TestPointsOnPath < Minitest::Test
  def setup
    @fixtures = JSON.parse(File.read(File.join(__dir__, "fixtures", "points_and_hachure.json")))
  end

  def test_points_on_path_matches_js
    @fixtures["points_on_path"].each_with_index do |fixture, fi|
      input = fixture["input"]

      [["output", nil], ["with_distance", 2]].each do |key, dist|
        expected = fixture[key]
        actual = Rough::PointsOnPath.points_on_path(input, 0.15, dist)
        assert_equal expected.length, actual.length, "Set count mismatch for #{key} fixture #{fi}"
        expected.each_with_index do |exp_set, si|
          assert_equal exp_set.length, actual[si].length,
            "Point count mismatch in set #{si} for #{key} fixture #{fi}: expected #{exp_set.length}, got #{actual[si].length}"
          exp_set.each_with_index do |exp_pt, pi|
            assert_in_delta exp_pt[0], actual[si][pi][0], 1e-10,
              "X mismatch at set #{si}, point #{pi} for #{key} fixture #{fi}"
            assert_in_delta exp_pt[1], actual[si][pi][1], 1e-10,
              "Y mismatch at set #{si}, point #{pi} for #{key} fixture #{fi}"
          end
        end
      end
    end
  end

  def test_simple_rect_path
    sets = Rough::PointsOnPath.points_on_path("M 0 0 L 100 0 L 100 100 L 0 100 Z")
    assert_equal 1, sets.length
    points = sets[0]
    assert points.length >= 5 # At least M + 4 L/Z points
  end
end
