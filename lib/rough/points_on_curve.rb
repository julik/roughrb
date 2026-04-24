# frozen_string_literal: true

module Rough
  module PointsOnCurve
    module_function

    def points_on_bezier_curves(points, tolerance = 0.15, distance = nil)
      new_points = []
      num_segments = (points.length - 1) / 3
      num_segments.times do |i|
        offset = i * 3
        get_points_on_bezier_curve_with_splitting(points, offset, tolerance, new_points)
      end
      if distance && distance > 0
        simplify_points(new_points, 0, new_points.length, distance)
      else
        new_points
      end
    end

    def simplify(points, distance)
      simplify_points(points, 0, points.length, distance)
    end

    def curve_to_bezier(points_in, curve_tightness = 0)
      len = points_in.length
      raise "A curve must have at least three points." if len < 3

      out = []
      if len == 3
        out.push(points_in[0].dup, points_in[1].dup, points_in[2].dup, points_in[2].dup)
      else
        points = []
        points.push(points_in[0], points_in[0])
        (1...points_in.length).each do |i|
          points.push(points_in[i])
          points.push(points_in[i]) if i == points_in.length - 1
        end

        s = 1 - curve_tightness
        out.push(points[0].dup)
        i = 1
        while (i + 2) < points.length
          cached = points[i]
          b1 = [
            cached[0] + (s * points[i + 1][0] - s * points[i - 1][0]) / 6.0,
            cached[1] + (s * points[i + 1][1] - s * points[i - 1][1]) / 6.0
          ]
          b2 = [
            points[i + 1][0] + (s * points[i][0] - s * points[i + 2][0]) / 6.0,
            points[i + 1][1] + (s * points[i][1] - s * points[i + 2][1]) / 6.0
          ]
          b3 = [points[i + 1][0], points[i + 1][1]]
          out.push(b1, b2, b3)
          i += 1
        end
      end
      out
    end

    # Private methods

    def self.distance(p1, p2)
      Math.sqrt(distance_sq(p1, p2))
    end

    def self.distance_sq(p1, p2)
      (p1[0] - p2[0])**2 + (p1[1] - p2[1])**2
    end

    def self.distance_to_segment_sq(p, v, w)
      l2 = distance_sq(v, w)
      return distance_sq(p, v) if l2 == 0
      t = ((p[0] - v[0]) * (w[0] - v[0]) + (p[1] - v[1]) * (w[1] - v[1])) / l2.to_f
      t = t.clamp(0, 1)
      distance_sq(p, lerp(v, w, t))
    end

    def self.lerp(a, b, t)
      [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
    end

    def self.flatness(points, offset)
      p1 = points[offset + 0]
      p2 = points[offset + 1]
      p3 = points[offset + 2]
      p4 = points[offset + 3]

      ux = 3 * p2[0] - 2 * p1[0] - p4[0]
      ux *= ux
      uy = 3 * p2[1] - 2 * p1[1] - p4[1]
      uy *= uy
      vx = 3 * p3[0] - 2 * p4[0] - p1[0]
      vx *= vx
      vy = 3 * p3[1] - 2 * p4[1] - p1[1]
      vy *= vy

      ux = vx if ux < vx
      uy = vy if uy < vy

      ux + uy
    end

    def self.get_points_on_bezier_curve_with_splitting(points, offset, tolerance, out_points)
      if flatness(points, offset) < tolerance
        p0 = points[offset + 0]
        if out_points.length > 0
          d = distance(out_points[-1], p0)
          out_points.push(p0) if d > 1
        else
          out_points.push(p0)
        end
        out_points.push(points[offset + 3])
      else
        t = 0.5
        p1 = points[offset + 0]
        p2 = points[offset + 1]
        p3 = points[offset + 2]
        p4 = points[offset + 3]

        q1 = lerp(p1, p2, t)
        q2 = lerp(p2, p3, t)
        q3 = lerp(p3, p4, t)

        r1 = lerp(q1, q2, t)
        r2 = lerp(q2, q3, t)

        red = lerp(r1, r2, t)

        get_points_on_bezier_curve_with_splitting([p1, q1, r1, red], 0, tolerance, out_points)
        get_points_on_bezier_curve_with_splitting([red, r2, q3, p4], 0, tolerance, out_points)
      end
      out_points
    end

    def self.simplify_points(points, start, end_idx, epsilon, out_points = nil)
      out_points ||= []

      s = points[start]
      e = points[end_idx - 1]
      max_dist_sq = 0
      max_ndx = 1
      ((start + 1)...(end_idx - 1)).each do |i|
        dist_sq = distance_to_segment_sq(points[i], s, e)
        if dist_sq > max_dist_sq
          max_dist_sq = dist_sq
          max_ndx = i
        end
      end

      if Math.sqrt(max_dist_sq) > epsilon
        simplify_points(points, start, max_ndx + 1, epsilon, out_points)
        simplify_points(points, max_ndx, end_idx, epsilon, out_points)
      else
        out_points.push(s) if out_points.empty?
        out_points.push(e)
      end

      out_points
    end

    private_class_method :distance, :distance_sq, :distance_to_segment_sq,
      :lerp, :flatness, :get_points_on_bezier_curve_with_splitting,
      :simplify_points
  end
end
