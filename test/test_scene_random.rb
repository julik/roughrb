# frozen_string_literal: true

require_relative "test_helper"

# Covers the scene-level Random API on Rough::Generator and Rough::SVG.
# When a `random:` (or `seed:`) is supplied at construction time, every
# subsequent shape pulls a fresh per-shape seed from that Random — so a
# whole scene becomes reproducible from a single integer.
class TestSceneRandom < Minitest::Test
  def test_same_random_seed_reproduces_full_scene
    a = render_scene(Rough::Generator.new(random: Random.new(42)))
    b = render_scene(Rough::Generator.new(random: Random.new(42)))
    assert_equal a, b, "two generators with identical random seeds must produce identical scenes"
  end

  def test_different_random_seeds_produce_different_scenes
    a = render_scene(Rough::Generator.new(random: Random.new(42)))
    b = render_scene(Rough::Generator.new(random: Random.new(43)))
    refute_equal a, b, "different rng seeds should produce different scenes"
  end

  def test_seed_kwarg_is_sugar_for_random
    a = render_scene(Rough::Generator.new(seed: 42))
    b = render_scene(Rough::Generator.new(random: Random.new(42)))
    assert_equal a, b, "Generator.new(seed: n) must equal Generator.new(random: Random.new(n))"
  end

  def test_consecutive_shapes_in_a_scene_differ
    gen = Rough::Generator.new(random: Random.new(42))
    a = flatten(gen.circle(50, 50, 100))
    b = flatten(gen.circle(50, 50, 100))
    refute_equal a, b, "two identical shapes in a single scene must differ (rng advanced)"
  end

  def test_per_shape_seed_overrides_random_draw
    rng = Random.new(42)
    gen = Rough::Generator.new(random: rng)

    # Shape passed an explicit seed: rng MUST NOT be consumed for it.
    explicit = flatten(gen.circle(50, 50, 100, seed: 7))

    # The next shape without an explicit seed should still get the FIRST
    # value from rng, proving the override didn't drain it.
    auto = flatten(gen.circle(50, 50, 100))

    expected_auto = flatten(
      Rough::Generator.new.circle(50, 50, 100, seed: Random.new(42).rand(Rough::Generator::SCENE_SEED_RANGE))
    )
    expected_explicit = flatten(Rough::Generator.new.circle(50, 50, 100, seed: 7))

    assert_equal expected_explicit, explicit, "explicit per-call seed must win"
    assert_equal expected_auto, auto, "explicit seed must not consume rng entropy"
  end

  def test_passing_both_random_and_seed_raises
    err = assert_raises(ArgumentError) do
      Rough::Generator.new(random: Random.new(1), seed: 2)
    end
    assert_match(/random.*seed/, err.message)
  end

  def test_no_random_means_unseeded_per_shape
    gen = Rough::Generator.new
    srand(1)
    a = flatten(gen.circle(50, 50, 100))
    srand(2)
    b = flatten(gen.circle(50, 50, 100))
    refute_equal a, b, "without random:/seed:, shapes fall through to Kernel#rand"
  end

  def test_svg_forwards_random_to_generator
    a = Rough::SVG.new(random: Random.new(42)).circle(50, 50, 100)
    b = Rough::SVG.new(random: Random.new(42)).circle(50, 50, 100)
    assert_equal a, b, "SVG.new(random:) must forward to its Generator"
  end

  def test_svg_forwards_seed_kwarg_to_generator
    a = Rough::SVG.new(seed: 42).circle(50, 50, 100)
    b = Rough::SVG.new(random: Random.new(42)).circle(50, 50, 100)
    assert_equal a, b
  end

  def test_random_attr_exposed_on_generator
    rng = Random.new(42)
    gen = Rough::Generator.new(random: rng)
    assert_same rng, gen.random
  end

  def test_dot_fill_is_deterministic_with_scene_random
    a = render_dots(Rough::Generator.new(random: Random.new(99)))
    b = render_dots(Rough::Generator.new(random: Random.new(99)))
    assert_equal a, b, "dot fills must be reproducible under a scene random"
  end

  private

  # A small but mixed scene that exercises stroke, fill, multiple shape kinds.
  def render_scene(gen)
    parts = []
    parts << flatten(gen.circle(50, 50, 100))
    parts << flatten(gen.rectangle(120, 10, 80, 80, fill: "red"))
    parts << flatten(gen.line(0, 0, 200, 200))
    parts << flatten(gen.polygon([[0, 0], [50, 0], [25, 50]], fill: "blue", fill_style: "cross-hatch"))
    parts << flatten(gen.curve([[0, 0], [50, 30], [100, 0]]))
    parts
  end

  def render_dots(gen)
    flatten(gen.rectangle(0, 0, 100, 100, fill: "red", fill_style: "dots"))
  end

  def flatten(drawable)
    drawable.sets.flat_map do |s|
      s.ops.flat_map { |op| [op.op] + op.data }
    end
  end
end
