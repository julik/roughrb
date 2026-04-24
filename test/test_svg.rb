require_relative "test_helper"

class TestSVG < Minitest::Test
  def setup
    @svg = Rough::SVG.new
  end

  def test_line_produces_svg
    result = @svg.line(0, 0, 100, 100, seed: 42)
    assert result.start_with?("<g>")
    assert result.end_with?("</g>")
    assert result.include?("<path ")
    assert result.include?('stroke="#000"')
    assert result.include?('fill="none"')
  end

  def test_rectangle_produces_svg
    result = @svg.rectangle(10, 10, 200, 100, seed: 42)
    assert result.include?("<path ")
  end

  def test_rectangle_with_fill
    result = @svg.rectangle(10, 10, 200, 100, seed: 42, fill: "red")
    assert result.include?('stroke="red"'), "Fill sketch should have fill color as stroke"
    assert result.include?('stroke="#000"'), "Outline should have default stroke"
  end

  def test_rectangle_with_solid_fill
    result = @svg.rectangle(10, 10, 200, 100, seed: 42, fill: "blue", fill_style: "solid")
    assert result.include?('fill="blue"')
  end

  def test_ellipse_produces_svg
    result = @svg.ellipse(100, 100, 150, 100, seed: 42)
    assert result.include?("<path ")
  end

  def test_circle_produces_svg
    result = @svg.circle(100, 100, 80, seed: 42)
    assert result.include?("<path ")
  end

  def test_polygon_produces_svg
    result = @svg.polygon([[0, 0], [100, 0], [50, 100]], seed: 42)
    assert result.include?("<path ")
  end

  def test_arc_produces_svg
    result = @svg.arc(100, 100, 200, 150, 0, Math::PI, seed: 42)
    assert result.include?("<path ")
  end

  def test_curve_produces_svg
    result = @svg.curve([[0, 0], [50, 100], [100, 50], [150, 100]], seed: 42)
    assert result.include?("<path ")
  end

  def test_path_produces_svg
    result = @svg.path("M 10 80 C 40 10, 65 10, 95 80", seed: 42)
    assert result.include?("<path ")
  end

  def test_stroke_dasharray
    result = @svg.line(0, 0, 100, 100, seed: 42, stroke_line_dash: [5, 3])
    assert result.include?('stroke-dasharray="5 3"')
  end

  def test_document_helper
    doc = Rough::SVG.document(400, 300) do |svg|
      svg.rectangle(10, 10, 380, 280, seed: 42)
    end
    assert doc.start_with?('<svg xmlns="http://www.w3.org/2000/svg"')
    assert doc.include?('width="400"')
    assert doc.include?('height="300"')
    assert doc.include?("<g>")
    assert doc.end_with?("</svg>")
  end

  def test_deterministic_svg_output
    s1 = @svg.line(0, 0, 100, 100, seed: 42)
    s2 = @svg.line(0, 0, 100, 100, seed: 42)
    assert_equal s1, s2
  end

  def test_polygon_fill_has_evenodd
    result = @svg.polygon([[0, 0], [100, 0], [50, 100]], seed: 42, fill: "green", fill_style: "solid")
    assert result.include?('fill-rule="evenodd"')
  end
end
