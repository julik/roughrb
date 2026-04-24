require_relative "options"
require_relative "op"
require_relative "random"
require_relative "renderer"
require_relative "points_on_curve"
require_relative "points_on_path"

module Rough
  class Generator
    attr_reader :default_options

    def initialize(**config_options)
      @default_options = ResolvedOptions.new(**config_options)
    end

    def self.new_seed
      Random.new_seed
    end

    def line(x1, y1, x2, y2, **options)
      o = _o(options)
      _d("line", [Renderer.line(x1, y1, x2, y2, o)], o)
    end

    def rectangle(x, y, width, height, **options)
      o = _o(options)
      paths = []
      outline = Renderer.rectangle(x, y, width, height, o)
      if o.fill
        points = [[x, y], [x + width, y], [x + width, y + height], [x, y + height]]
        paths << if o.fill_style == "solid"
          Renderer.solid_fill_polygon([points], o)
        else
          Renderer.pattern_fill_polygons([points], o)
        end
      end
      paths << outline if o.stroke != "none"
      _d("rectangle", paths, o)
    end

    def ellipse(x, y, width, height, **options)
      o = _o(options)
      paths = []
      ellipse_params = Renderer.generate_ellipse_params(width, height, o)
      ellipse_response = Renderer.ellipse_with_params(x, y, o, ellipse_params)
      if o.fill
        if o.fill_style == "solid"
          shape = Renderer.ellipse_with_params(x, y, o, ellipse_params)[:opset]
          shape.type = :fillPath
          paths << shape
        else
          paths << Renderer.pattern_fill_polygons([ellipse_response[:estimated_points]], o)
        end
      end
      paths << ellipse_response[:opset] if o.stroke != "none"
      _d("ellipse", paths, o)
    end

    def circle(x, y, diameter, **options)
      ret = ellipse(x, y, diameter, diameter, **options)
      ret.shape = "circle"
      ret
    end

    def linear_path(points, **options)
      o = _o(options)
      _d("linearPath", [Renderer.linear_path(points, false, o)], o)
    end

    def arc(x, y, width, height, start, stop, closed: false, **options)
      o = _o(options)
      paths = []
      outline = Renderer.arc(x, y, width, height, start, stop, closed, true, o)
      if closed && o.fill
        if o.fill_style == "solid"
          fill_options = o.merge(disable_multi_stroke: true)
          shape = Renderer.arc(x, y, width, height, start, stop, true, false, fill_options)
          shape.type = :fillPath
          paths << shape
        else
          paths << Renderer.pattern_fill_arc(x, y, width, height, start, stop, o)
        end
      end
      paths << outline if o.stroke != "none"
      _d("arc", paths, o)
    end

    def curve(points, **options)
      o = _o(options)
      paths = []
      outline = Renderer.curve(points, o)
      if o.fill && o.fill != "none"
        if o.fill_style == "solid"
          fill_shape = Renderer.curve(points, o.merge(
            disable_multi_stroke: true,
            roughness: (o.roughness != 0) ? (o.roughness + o.fill_shape_roughness_gain) : 0
          ))
          paths << OpSet.new(type: :fillPath, ops: _merged_shape(fill_shape.ops))
        else
          poly_points = []
          input_points = points
          if input_points.length > 0
            p1 = input_points[0]
            points_list = p1[0].is_a?(Numeric) ? [input_points] : input_points
            points_list.each do |pts|
              if pts.length < 3
                poly_points.concat(pts)
              elsif pts.length == 3
                poly_points.concat(
                  PointsOnCurve.points_on_bezier_curves(
                    PointsOnCurve.curve_to_bezier([pts[0], pts[0], pts[1], pts[2]]),
                    10, (1 + o.roughness) / 2.0
                  )
                )
              else
                poly_points.concat(
                  PointsOnCurve.points_on_bezier_curves(
                    PointsOnCurve.curve_to_bezier(pts), 10, (1 + o.roughness) / 2.0
                  )
                )
              end
            end
          end
          paths << Renderer.pattern_fill_polygons([poly_points], o) if poly_points.length > 0
        end
      end
      paths << outline if o.stroke != "none"
      _d("curve", paths, o)
    end

    def polygon(points, **options)
      o = _o(options)
      paths = []
      outline = Renderer.linear_path(points, true, o)
      if o.fill
        paths << if o.fill_style == "solid"
          Renderer.solid_fill_polygon([points], o)
        else
          Renderer.pattern_fill_polygons([points], o)
        end
      end
      paths << outline if o.stroke != "none"
      _d("polygon", paths, o)
    end

    def path(d, **options)
      o = _o(options)
      paths = []
      return _d("path", paths, o) unless d

      d = (d || "").tr("\n", " ").gsub(/-\s/, "-").gsub(/\s\s/, " ")

      has_fill = o.fill && o.fill != "transparent" && o.fill != "none"
      has_stroke = o.stroke != "none"
      simplified = !!(o.simplification && o.simplification < 1)
      distance = simplified ? (4 - 4 * (o.simplification || 1)) : ((1 + o.roughness) / 2.0)
      sets = PointsOnPath.points_on_path(d, 1, distance)
      shape = Renderer.svg_path(d, o)

      if has_fill
        if o.fill_style == "solid"
          if sets.length == 1
            fill_shape = Renderer.svg_path(d, o.merge(
              disable_multi_stroke: true,
              roughness: (o.roughness != 0) ? (o.roughness + o.fill_shape_roughness_gain) : 0
            ))
            paths << OpSet.new(type: :fillPath, ops: _merged_shape(fill_shape.ops))
          else
            paths << Renderer.solid_fill_polygon(sets, o)
          end
        else
          paths << Renderer.pattern_fill_polygons(sets, o)
        end
      end

      if has_stroke
        if simplified
          sets.each { |set| paths << Renderer.linear_path(set, false, o) }
        else
          paths << shape
        end
      end

      _d("path", paths, o)
    end

    def ops_to_path(drawing, fixed_decimals = nil)
      path = ""
      drawing.ops.each do |item|
        data = if fixed_decimals.is_a?(Integer) && fixed_decimals >= 0
          item.data.map { |d| d.round(fixed_decimals) }
        else
          item.data
        end
        case item.op
        when :move
          path += "M#{data[0]} #{data[1]} "
        when :bcurveTo
          path += "C#{data[0]} #{data[1]}, #{data[2]} #{data[3]}, #{data[4]} #{data[5]} "
        when :lineTo
          path += "L#{data[0]} #{data[1]} "
        end
      end
      path.strip
    end

    def to_paths(drawable)
      sets = drawable.sets || []
      o = drawable.options || @default_options
      paths = []
      sets.each do |drawing|
        pi = case drawing.type
        when :path
          PathInfo.new(
            d: ops_to_path(drawing),
            stroke: o.stroke,
            stroke_width: o.stroke_width,
            fill: "none"
          )
        when :fillPath
          PathInfo.new(
            d: ops_to_path(drawing),
            stroke: "none",
            stroke_width: 0,
            fill: o.fill || "none"
          )
        when :fillSketch
          _fill_sketch_path(drawing, o)
        end
        paths << pi if pi
      end
      paths
    end

    private

    def _o(options)
      options.empty? ? @default_options : @default_options.merge(**options)
    end

    def _d(shape, sets, options)
      Drawable.new(shape: shape, sets: sets || [], options: options || @default_options)
    end

    def _fill_sketch_path(drawing, o)
      fweight = o.fill_weight
      fweight = o.stroke_width / 2.0 if fweight < 0
      PathInfo.new(
        d: ops_to_path(drawing),
        stroke: o.fill || "none",
        stroke_width: fweight,
        fill: "none"
      )
    end

    def _merged_shape(input)
      input.each_with_index.select { |op, i| i == 0 || op.op != :move }.map(&:first)
    end
  end
end
