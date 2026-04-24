require_relative "hachure"
require_relative "scan_line_hachure"
require_relative "../geometry"

module Rough
  module Fillers
    class Zigzag < Hachure
      def fill_polygons(polygon_list, o)
        gap = o.hachure_gap
        gap = o.stroke_width * 4 if gap < 0
        gap = [gap, 0.1].max
        o2 = o.merge(hachure_gap: gap)
        lines = ScanLineHachure.polygon_hachure_lines(polygon_list, o2)
        zig_zag_angle = (Math::PI / 180) * o.hachure_angle
        zigzag_lines = []
        dgx = gap * 0.5 * Math.cos(zig_zag_angle)
        dgy = gap * 0.5 * Math.sin(zig_zag_angle)
        lines.each do |line|
          p1, p2 = line
          if Geometry.line_length([p1, p2]) > 0
            zigzag_lines << [[p1[0] - dgx, p1[1] + dgy], p2.dup]
            zigzag_lines << [[p1[0] + dgx, p1[1] - dgy], p2.dup]
          end
        end
        ops = render_lines(zigzag_lines, o)
        OpSet.new(type: :fillSketch, ops: ops)
      end
    end
  end
end
