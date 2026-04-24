module Rough
  module HachureFill
    module_function

    def hachure_lines(polygons, hachure_gap, hachure_angle, hachure_step_offset = 1)
      gap = [hachure_gap, 0.1].max
      # Detect if single polygon passed as [[x,y], ...] vs [[[x,y], ...], ...]
      polygon_list = if polygons[0] && polygons[0][0] && polygons[0][0].is_a?(Numeric)
        [polygons]
      else
        polygons
      end

      rotation_center = [0, 0]

      if hachure_angle != 0
        polygon_list.each { |polygon| rotate_points(polygon, rotation_center, hachure_angle) }
      end

      lines = straight_hachure_lines(polygon_list, gap, hachure_step_offset)

      if hachure_angle != 0
        polygon_list.each { |polygon| rotate_points(polygon, rotation_center, -hachure_angle) }
        rotate_lines(lines, rotation_center, -hachure_angle)
      end

      lines
    end

    def self.rotate_points(points, center, degrees)
      return unless points && points.length > 0
      cx, cy = center
      angle = (Math::PI / 180) * degrees
      cos = Math.cos(angle)
      sin = Math.sin(angle)
      points.each do |p|
        x, y = p
        p[0] = ((x - cx) * cos) - ((y - cy) * sin) + cx
        p[1] = ((x - cx) * sin) + ((y - cy) * cos) + cy
      end
    end

    def self.rotate_lines(lines, center, degrees)
      points = []
      lines.each { |line| points.concat(line) }
      rotate_points(points, center, degrees)
    end

    def self.straight_hachure_lines(polygons, gap, hachure_step_offset)
      vertex_array = []
      polygons.each do |polygon|
        vertices = polygon.map(&:dup)
        unless vertices[0][0] == vertices[-1][0] && vertices[0][1] == vertices[-1][1]
          vertices.push([vertices[0][0], vertices[0][1]])
        end
        vertex_array.push(vertices) if vertices.length > 2
      end

      lines = []
      gap = [gap, 0.1].max

      # Create sorted edges table
      edges = []
      vertex_array.each do |vertices|
        (0...vertices.length - 1).each do |i|
          p1 = vertices[i]
          p2 = vertices[i + 1]
          next if p1[1] == p2[1]
          ymin = [p1[1], p2[1]].min
          edges << {
            ymin: ymin,
            ymax: [p1[1], p2[1]].max,
            x: ymin == p1[1] ? p1[0] : p2[0],
            islope: (p2[0] - p1[0]).to_f / (p2[1] - p1[1])
          }
        end
      end

      edges.sort! do |e1, e2|
        if e1[:ymin] < e2[:ymin]
          -1
        elsif e1[:ymin] > e2[:ymin]
          1
        elsif e1[:x] < e2[:x]
          -1
        elsif e1[:x] > e2[:x]
          1
        elsif e1[:ymax] == e2[:ymax]
          0
        else
          (e1[:ymax] - e2[:ymax]) <=> 0
        end
      end

      return lines if edges.empty?

      # Start scanning
      active_edges = []
      y = edges[0][:ymin]
      iteration = 0

      while active_edges.length > 0 || edges.length > 0
        if edges.length > 0
          ix = -1
          edges.each_with_index do |edge, i|
            break if edge[:ymin] > y
            ix = i
          end
          removed = edges.slice!(0, ix + 1)
          removed.each { |edge| active_edges << {s: y, edge: edge} }
        end

        active_edges.reject! { |ae| ae[:edge][:ymax] <= y }

        active_edges.sort! do |ae1, ae2|
          ae1[:edge][:x] <=> ae2[:edge][:x]
        end

        # Fill between edges
        if hachure_step_offset != 1 || (iteration % gap == 0)
          if active_edges.length > 1
            i = 0
            while i < active_edges.length
              nexti = i + 1
              break if nexti >= active_edges.length
              ce = active_edges[i][:edge]
              ne = active_edges[nexti][:edge]
              lines << [
                [ce[:x].round, y],
                [ne[:x].round, y]
              ]
              i += 2
            end
          end
        end

        y += hachure_step_offset
        active_edges.each { |ae| ae[:edge][:x] += hachure_step_offset * ae[:edge][:islope] }
        iteration += 1
      end

      lines
    end

    private_class_method :rotate_points, :rotate_lines, :straight_hachure_lines
  end
end
