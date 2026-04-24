# frozen_string_literal: true

module Rough
  # Points are [x, y] arrays. Lines are [[x1,y1], [x2,y2]].
  module Geometry
    module_function

    def line_length(line)
      p1, p2 = line
      Math.sqrt((p1[0] - p2[0])**2 + (p1[1] - p2[1])**2)
    end
  end
end
