require_relative "test_helper"
require "rough/geometry"

class TestGeometry < Minitest::Test
  def test_line_length_horizontal
    assert_in_delta 5.0, Rough::Geometry.line_length([[0, 0], [5, 0]])
  end

  def test_line_length_vertical
    assert_in_delta 3.0, Rough::Geometry.line_length([[0, 0], [0, 3]])
  end

  def test_line_length_diagonal
    assert_in_delta 5.0, Rough::Geometry.line_length([[0, 0], [3, 4]])
  end

  def test_line_length_zero
    assert_in_delta 0.0, Rough::Geometry.line_length([[7, 7], [7, 7]])
  end

  def test_line_length_negative_coords
    assert_in_delta 5.0, Rough::Geometry.line_length([[-3, -4], [0, 0]])
  end
end
