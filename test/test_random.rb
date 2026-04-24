# frozen_string_literal: true

require_relative "test_helper"
require "rough/random"

class TestRandom < Minitest::Test
  def setup
    @fixtures = JSON.parse(File.read(File.join(__dir__, "fixtures", "random.json")))
  end

  def test_deterministic_sequences_match_js
    @fixtures.each do |seed_str, expected_values|
      seed = seed_str.to_i
      rng = Rough::Random.new(seed)
      expected_values.each_with_index do |expected, i|
        actual = rng.next
        assert_in_delta expected, actual, 1e-15,
          "Seed #{seed}, iteration #{i}: expected #{expected}, got #{actual}"
      end
    end
  end

  def test_next_returns_float_in_0_1
    rng = Rough::Random.new(42)
    100.times do
      v = rng.next
      assert v >= 0.0 && v < 1.0, "Expected [0,1), got #{v}"
    end
  end

  def test_new_seed_returns_integer
    seed = Rough::Random.new_seed
    assert_kind_of Integer, seed
    assert seed >= 0
    assert seed < 2**31
  end

  def test_zero_seed_uses_kernel_rand
    rng = Rough::Random.new(0)
    values = Array.new(10) { rng.next }
    # Non-deterministic, but should be in range
    values.each { |v| assert v >= 0.0 && v < 1.0 }
  end
end
