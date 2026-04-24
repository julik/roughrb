require_relative "path_data_parser"
require_relative "points_on_curve"

module Rough
  module PointsOnPath
    module_function

    def points_on_path(path, tolerance = nil, distance = nil)
      segments = PathDataParser.parse(path)
      normalized = PathDataParser.normalize(PathDataParser.absolutize(segments))

      sets = []
      current_points = []
      start = [0, 0]
      pending_curve = []

      append_pending_curve = -> {
        if pending_curve.length >= 4
          current_points.concat(PointsOnCurve.points_on_bezier_curves(pending_curve, tolerance || 0.15))
        end
        pending_curve = []
      }

      append_pending_points = -> {
        append_pending_curve.call
        if current_points.length > 0
          sets << current_points
          current_points = []
        end
      }

      normalized.each do |seg|
        case seg.key
        when "M"
          append_pending_points.call
          start = [seg.data[0], seg.data[1]]
          current_points << start
        when "L"
          append_pending_curve.call
          current_points << [seg.data[0], seg.data[1]]
        when "C"
          if pending_curve.empty?
            last_point = (current_points.length > 0) ? current_points[-1] : start
            pending_curve << [last_point[0], last_point[1]]
          end
          pending_curve << [seg.data[0], seg.data[1]]
          pending_curve << [seg.data[2], seg.data[3]]
          pending_curve << [seg.data[4], seg.data[5]]
        when "Z"
          append_pending_curve.call
          current_points << [start[0], start[1]]
        end
      end

      append_pending_points.call

      return sets unless distance && distance > 0

      sets.map do |set|
        simplified = PointsOnCurve.simplify(set, distance)
        (simplified.length > 0) ? simplified : nil
      end.compact
    end
  end
end
