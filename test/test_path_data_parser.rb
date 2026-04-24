require_relative "test_helper"
require "rough/path_data_parser"

class TestPathDataParser < Minitest::Test
  def setup
    @fixtures = JSON.parse(File.read(File.join(__dir__, "fixtures", "path_data_parser.json")))
  end

  def test_parse_matches_js
    @fixtures.each do |path_str, expected|
      parsed = Rough::PathDataParser.parse(path_str)
      expected_parsed = expected["parsed"]
      assert_equal expected_parsed.length, parsed.length, "Segment count mismatch for '#{path_str}'"
      expected_parsed.each_with_index do |exp_seg, i|
        assert_equal exp_seg["key"], parsed[i].key, "Key mismatch at segment #{i} for '#{path_str}'"
        assert_data_equal exp_seg["data"], parsed[i].data, "Data mismatch at segment #{i} for '#{path_str}'"
      end
    end
  end

  def test_absolutize_matches_js
    @fixtures.each do |path_str, expected|
      parsed = Rough::PathDataParser.parse(path_str)
      abs = Rough::PathDataParser.absolutize(parsed)
      expected_abs = expected["absolutized"]
      assert_equal expected_abs.length, abs.length, "Segment count mismatch for absolutize '#{path_str}'"
      expected_abs.each_with_index do |exp_seg, i|
        assert_equal exp_seg["key"], abs[i].key, "Key mismatch at segment #{i} for absolutize '#{path_str}'"
        assert_data_equal exp_seg["data"], abs[i].data, "Data mismatch at segment #{i} for absolutize '#{path_str}'"
      end
    end
  end

  def test_normalize_matches_js
    @fixtures.each do |path_str, expected|
      parsed = Rough::PathDataParser.parse(path_str)
      abs = Rough::PathDataParser.absolutize(parsed)
      norm = Rough::PathDataParser.normalize(abs)
      expected_norm = expected["normalized"]
      assert_equal expected_norm.length, norm.length, "Segment count mismatch for normalize '#{path_str}'"
      expected_norm.each_with_index do |exp_seg, i|
        assert_equal exp_seg["key"], norm[i].key, "Key mismatch at segment #{i} for normalize '#{path_str}'"
        assert_data_equal exp_seg["data"], norm[i].data, "Data mismatch at segment #{i} for normalize '#{path_str}'"
      end
    end
  end

  def test_parse_simple_line
    segs = Rough::PathDataParser.parse("M 10 80 L 100 80")
    assert_equal 2, segs.length
    assert_equal "M", segs[0].key
    assert_equal [10.0, 80.0], segs[0].data
    assert_equal "L", segs[1].key
    assert_equal [100.0, 80.0], segs[1].data
  end

  def test_parse_implicit_moveto_prefix
    # Same behavior as JS: "100 200" prepends "M0,0" making "M0,0100 200"
    # which is malformed and raises an error
    assert_raises(RuntimeError) { Rough::PathDataParser.parse("100 200") }
  end

  private

  def assert_data_equal(expected, actual, msg = "")
    assert_equal expected.length, actual.length, "#{msg}: data length"
    expected.each_with_index do |exp_val, i|
      assert_in_delta exp_val, actual[i], 1e-10, "#{msg}: index #{i}"
    end
  end
end
