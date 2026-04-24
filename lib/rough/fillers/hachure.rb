require_relative "scan_line_hachure"

module Rough
  module Fillers
    class Hachure
      def initialize(helper)
        @helper = helper
      end

      def fill_polygons(polygon_list, o)
        _fill_polygons(polygon_list, o)
      end

      protected

      def _fill_polygons(polygon_list, o)
        lines = ScanLineHachure.polygon_hachure_lines(polygon_list, o)
        ops = render_lines(lines, o)
        OpSet.new(type: :fillSketch, ops: ops)
      end

      def render_lines(lines, o)
        ops = []
        lines.each do |line|
          ops.concat(@helper.double_line_ops(line[0][0], line[0][1], line[1][0], line[1][1], o))
        end
        ops
      end
    end
  end
end
