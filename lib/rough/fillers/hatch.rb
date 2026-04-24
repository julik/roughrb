require_relative "hachure"

module Rough
  module Fillers
    class Hatch < Hachure
      def fill_polygons(polygon_list, o)
        set = _fill_polygons(polygon_list, o)
        o2 = o.merge(hachure_angle: o.hachure_angle + 90)
        set2 = _fill_polygons(polygon_list, o2)
        set.ops = set.ops + set2.ops
        set
      end
    end
  end
end
