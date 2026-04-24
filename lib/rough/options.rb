module Rough
  DEFAULTS = {
    max_randomness_offset: 2,
    roughness: 1,
    bowing: 1,
    stroke: "#000",
    stroke_width: 1,
    curve_tightness: 0,
    curve_fitting: 0.95,
    curve_step_count: 9,
    fill: nil,
    fill_style: "hachure",
    fill_weight: -1,
    hachure_angle: -41,
    hachure_gap: -1,
    simplification: nil,
    dash_offset: -1,
    dash_gap: -1,
    zigzag_offset: -1,
    seed: 0,
    stroke_line_dash: nil,
    stroke_line_dash_offset: nil,
    fill_line_dash: nil,
    fill_line_dash_offset: nil,
    disable_multi_stroke: false,
    disable_multi_stroke_fill: false,
    preserve_vertices: false,
    fixed_decimal_place_digits: nil,
    fill_shape_roughness_gain: 0.8,
  }.freeze

  # Resolved options with all defaults filled in.
  # Behaves like a read-only hash-like object.
  class ResolvedOptions
    FIELDS = DEFAULTS.keys + [:randomizer]

    FIELDS.each do |field|
      attr_accessor field
    end

    def initialize(**overrides)
      DEFAULTS.each { |k, v| send(:"#{k}=", v) }
      overrides.each { |k, v| send(:"#{k}=", v) }
    end

    def merge(**overrides)
      dup.tap do |o|
        overrides.each { |k, v| o.send(:"#{k}=", v) }
      end
    end
  end
end
