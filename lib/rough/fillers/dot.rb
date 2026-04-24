require_relative "scan_line_hachure"
require_relative "../geometry"

module Rough
  module Fillers
    class Dot
      def initialize(helper)
        @helper = helper
      end

      def fill_polygons(polygon_list, o)
        o2 = o.merge(hachure_angle: 0)
        lines = ScanLineHachure.polygon_hachure_lines(polygon_list, o2)
        dots_on_lines(lines, o2)
      end

      private

      def dots_on_lines(lines, o)
        ops = []
        gap = o.hachure_gap
        gap = o.stroke_width * 4 if gap < 0
        gap = [gap, 0.1].max
        fweight = o.fill_weight
        fweight = o.stroke_width / 2.0 if fweight < 0
        ro = gap / 4.0
        lines.each do |line|
          length = Geometry.line_length(line)
          dl = length / gap
          count = dl.ceil - 1
          offset = length - (count * gap)
          x = ((line[0][0] + line[1][0]) / 2.0) - (gap / 4.0)
          min_y = [line[0][1], line[1][1]].min

          count.times do |i|
            y = min_y + offset + (i * gap)
            cx = (x - ro) + rand * 2 * ro
            cy = (y - ro) + rand * 2 * ro
            el = @helper.ellipse(cx, cy, fweight, fweight, o)
            ops.concat(el.ops)
          end
        end
        OpSet.new(type: :fillSketch, ops: ops)
      end
    end
  end
end
