require_relative "scan_line_hachure"
require_relative "../geometry"

module Rough
  module Fillers
    class Dashed
      def initialize(helper)
        @helper = helper
      end

      def fill_polygons(polygon_list, o)
        lines = ScanLineHachure.polygon_hachure_lines(polygon_list, o)
        OpSet.new(type: :fillSketch, ops: dashed_line(lines, o))
      end

      private

      def dashed_line(lines, o)
        offset = o.dash_offset < 0 ? (o.hachure_gap < 0 ? (o.stroke_width * 4) : o.hachure_gap) : o.dash_offset
        gap = o.dash_gap < 0 ? (o.hachure_gap < 0 ? (o.stroke_width * 4) : o.hachure_gap) : o.dash_gap
        ops = []
        lines.each do |line|
          length = Geometry.line_length(line)
          count = (length / (offset + gap)).floor
          start_offset = (length + gap - (count * (offset + gap))) / 2.0
          p1, p2 = line
          if p1[0] > p2[0]
            p1, p2 = p2, p1
          end
          alpha = Math.atan((p2[1] - p1[1]).to_f / (p2[0] - p1[0]))
          count.times do |i|
            lstart = i * (offset + gap)
            lend = lstart + offset
            start_pt = [
              p1[0] + lstart * Math.cos(alpha) + start_offset * Math.cos(alpha),
              p1[1] + lstart * Math.sin(alpha) + start_offset * Math.sin(alpha)
            ]
            end_pt = [
              p1[0] + lend * Math.cos(alpha) + start_offset * Math.cos(alpha),
              p1[1] + lend * Math.sin(alpha) + start_offset * Math.sin(alpha)
            ]
            ops.concat(@helper.double_line_ops(start_pt[0], start_pt[1], end_pt[0], end_pt[1], o))
          end
        end
        ops
      end
    end
  end
end
