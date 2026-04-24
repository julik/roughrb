require_relative "../hachure_fill"

module Rough
  module Fillers
    module ScanLineHachure
      module_function

      def polygon_hachure_lines(polygon_list, o)
        angle = o.hachure_angle + 90
        gap = o.hachure_gap
        gap = o.stroke_width * 4 if gap < 0
        gap = [gap.round, 0.1].max

        skip_offset = 1
        if o.roughness >= 1
          rng_val = o.randomizer ? o.randomizer.next : rand
          skip_offset = gap if rng_val > 0.7
        end

        HachureFill.hachure_lines(polygon_list, gap, angle, skip_offset == 0 ? 1 : skip_offset)
      end
    end
  end
end
