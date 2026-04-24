module Rough
  # A single drawing primitive: :move, :bcurveTo, or :lineTo
  Op = Struct.new(:op, :data, keyword_init: true)

  # A group of Ops forming a stroke or fill.
  # type: :path, :fillPath, or :fillSketch
  OpSet = Struct.new(:type, :ops, :size, :path, keyword_init: true)

  # The complete renderable result.
  Drawable = Struct.new(:shape, :options, :sets, keyword_init: true)

  # SVG path data representation.
  PathInfo = Struct.new(:d, :stroke, :stroke_width, :fill, keyword_init: true)
end
