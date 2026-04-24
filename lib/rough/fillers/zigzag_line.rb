require_relative "scan_line_hachure"
require_relative "../geometry"

module Rough
  module Fillers
    class ZigzagLine
      def initialize(helper)
        @helper = helper
      end

      def fill_polygons(polygon_list, o)
        gap = (o.hachure_gap < 0) ? (o.stroke_width * 4) : o.hachure_gap
        zo = (o.zigzag_offset < 0) ? gap : o.zigzag_offset
        o2 = o.merge(hachure_gap: gap + zo)
        lines = ScanLineHachure.polygon_hachure_lines(polygon_list, o2)
        OpSet.new(type: :fillSketch, ops: zigzag_lines(lines, zo, o2))
      end

      private

      def zigzag_lines(lines, zo, o)
        ops = []
        lines.each do |line|
          length = Geometry.line_length(line)
          count = (length / (2 * zo)).round
          p1, p2 = line
          if p1[0] > p2[0]
            p1, p2 = p2, p1
          end
          alpha = Math.atan((p2[1] - p1[1]).to_f / (p2[0] - p1[0]))
          count.times do |i|
            lstart = i * 2 * zo
            lend = (i + 1) * 2 * zo
            dz = Math.sqrt(2 * zo**2)
            start_pt = [p1[0] + lstart * Math.cos(alpha), p1[1] + lstart * Math.sin(alpha)]
            end_pt = [p1[0] + lend * Math.cos(alpha), p1[1] + lend * Math.sin(alpha)]
            middle = [start_pt[0] + dz * Math.cos(alpha + Math::PI / 4), start_pt[1] + dz * Math.sin(alpha + Math::PI / 4)]
            ops.concat(@helper.double_line_ops(start_pt[0], start_pt[1], middle[0], middle[1], o))
            ops.concat(@helper.double_line_ops(middle[0], middle[1], end_pt[0], end_pt[1], o))
          end
        end
        ops
      end
    end
  end
end
