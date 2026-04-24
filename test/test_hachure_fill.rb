require_relative "test_helper"
require "rough/hachure_fill"

class TestHachureFill < Minitest::Test
  def setup
    @fixtures = JSON.parse(File.read(File.join(__dir__, "fixtures", "points_and_hachure.json")))
  end

  def test_hachure_lines_match_js
    @fixtures["hachure_lines"].each_with_index do |fixture, fi|
      input = fixture["input"].map { |poly| poly.map(&:dup) }
      expected = fixture["output"]
      actual = Rough::HachureFill.hachure_lines(input, fixture["gap"], fixture["angle"], fixture["skip"])

      assert_equal expected.length, actual.length, "Line count mismatch for fixture #{fi} (angle=#{fixture["angle"]}, gap=#{fixture["gap"]})"
      expected.each_with_index do |exp_line, i|
        2.times do |j|
          assert_in_delta exp_line[j][0], actual[i][j][0], 1e-8,
            "X mismatch at line #{i}, point #{j} for fixture #{fi}"
          assert_in_delta exp_line[j][1], actual[i][j][1], 1e-8,
            "Y mismatch at line #{i}, point #{j} for fixture #{fi}"
        end
      end
    end
  end

  def test_hachure_lines_simple_rect
    rect = [[0, 0], [100, 0], [100, 100], [0, 100]]
    lines = Rough::HachureFill.hachure_lines([rect], 10, 0, 1)
    refute_empty lines
    # All lines should be horizontal (same y for both endpoints)
    lines.each do |line|
      assert_equal line[0][1], line[1][1], "Hachure line should be horizontal at angle 0"
    end
  end
end
