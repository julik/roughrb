require_relative "random"
require_relative "op"
require_relative "options"
require_relative "path_data_parser"

module Rough
  module Renderer
    module_function

    def line(x1, y1, x2, y2, o)
      OpSet.new(type: :path, ops: _double_line(x1, y1, x2, y2, o))
    end

    def linear_path(points, close, o)
      len = (points || []).length
      if len > 2
        ops = []
        (0...(len - 1)).each do |i|
          ops.concat(_double_line(points[i][0], points[i][1], points[i + 1][0], points[i + 1][1], o))
        end
        if close
          ops.concat(_double_line(points[len - 1][0], points[len - 1][1], points[0][0], points[0][1], o))
        end
        OpSet.new(type: :path, ops: ops)
      elsif len == 2
        line(points[0][0], points[0][1], points[1][0], points[1][1], o)
      else
        OpSet.new(type: :path, ops: [])
      end
    end

    def polygon(points, o)
      linear_path(points, true, o)
    end

    def rectangle(x, y, width, height, o)
      points = [[x, y], [x + width, y], [x + width, y + height], [x, y + height]]
      polygon(points, o)
    end

    def curve(input_points, o)
      if input_points.length > 0
        p1 = input_points[0]
        points_list = p1[0].is_a?(Numeric) ? [input_points] : input_points

        o1 = _curve_with_offset(points_list[0], 1 * (1 + o.roughness * 0.2), o)
        o2 = o.disable_multi_stroke ? [] : _curve_with_offset(points_list[0], 1.5 * (1 + o.roughness * 0.22), clone_options_alter_seed(o))

        (1...points_list.length).each do |i|
          pts = points_list[i]
          next unless pts.length > 0
          underlay = _curve_with_offset(pts, 1 * (1 + o.roughness * 0.2), o)
          overlay = o.disable_multi_stroke ? [] : _curve_with_offset(pts, 1.5 * (1 + o.roughness * 0.22), clone_options_alter_seed(o))
          underlay.each { |item| o1 << item if item.op != :move }
          overlay.each { |item| o2 << item if item.op != :move }
        end

        OpSet.new(type: :path, ops: o1 + o2)
      else
        OpSet.new(type: :path, ops: [])
      end
    end

    def ellipse(x, y, width, height, o)
      params = generate_ellipse_params(width, height, o)
      ellipse_with_params(x, y, o, params)[:opset]
    end

    def generate_ellipse_params(width, height, o)
      psq = Math.sqrt(Math::PI * 2 * Math.sqrt(((width / 2.0)**2 + (height / 2.0)**2) / 2.0))
      step_count = [o.curve_step_count, (o.curve_step_count / Math.sqrt(200)) * psq].max.ceil
      increment = (Math::PI * 2) / step_count
      rx = (width / 2.0).abs
      ry = (height / 2.0).abs
      curve_fit_randomness = 1 - o.curve_fitting
      rx += _offset_opt(rx * curve_fit_randomness, o)
      ry += _offset_opt(ry * curve_fit_randomness, o)
      {increment: increment, rx: rx, ry: ry}
    end

    def ellipse_with_params(x, y, o, ellipse_params)
      ap1, cp1 = _compute_ellipse_points(
        ellipse_params[:increment], x, y, ellipse_params[:rx], ellipse_params[:ry],
        1, ellipse_params[:increment] * _offset(0.1, _offset(0.4, 1, o), o), o
      )
      o1 = _curve_ops(ap1, nil, o)
      if !o.disable_multi_stroke && o.roughness != 0
        ap2, _ = _compute_ellipse_points(ellipse_params[:increment], x, y, ellipse_params[:rx], ellipse_params[:ry], 1.5, 0, o)
        o2 = _curve_ops(ap2, nil, o)
        o1 += o2
      end
      {
        estimated_points: cp1,
        opset: OpSet.new(type: :path, ops: o1)
      }
    end

    def arc(x, y, width, height, start, stop, closed, rough_closure, o)
      cx = x
      cy = y
      rx = (width / 2.0).abs
      ry = (height / 2.0).abs
      rx += _offset_opt(rx * 0.01, o)
      ry += _offset_opt(ry * 0.01, o)
      strt = start
      stp = stop
      while strt < 0
        strt += Math::PI * 2
        stp += Math::PI * 2
      end
      if (stp - strt) > (Math::PI * 2)
        strt = 0
        stp = Math::PI * 2
      end
      ellipse_inc = (Math::PI * 2) / o.curve_step_count
      arc_inc = [ellipse_inc / 2.0, (stp - strt) / 2.0].min
      ops = _arc(arc_inc, cx, cy, rx, ry, strt, stp, 1, o)
      unless o.disable_multi_stroke
        o2 = _arc(arc_inc, cx, cy, rx, ry, strt, stp, 1.5, o)
        ops.concat(o2)
      end
      if closed
        if rough_closure
          ops.concat(_double_line(cx, cy, cx + rx * Math.cos(strt), cy + ry * Math.sin(strt), o))
          ops.concat(_double_line(cx, cy, cx + rx * Math.cos(stp), cy + ry * Math.sin(stp), o))
        else
          ops << Op.new(op: :lineTo, data: [cx, cy])
          ops << Op.new(op: :lineTo, data: [cx + rx * Math.cos(strt), cy + ry * Math.sin(strt)])
        end
      end
      OpSet.new(type: :path, ops: ops)
    end

    def svg_path(path, o)
      segments = PathDataParser.normalize(PathDataParser.absolutize(PathDataParser.parse(path)))
      ops = []
      first = [0, 0]
      current = [0, 0]
      segments.each do |seg|
        case seg.key
        when "M"
          current = [seg.data[0], seg.data[1]]
          first = [seg.data[0], seg.data[1]]
        when "L"
          ops.concat(_double_line(current[0], current[1], seg.data[0], seg.data[1], o))
          current = [seg.data[0], seg.data[1]]
        when "C"
          x1, y1, x2, y2, x, y = seg.data
          ops.concat(_bezier_to(x1, y1, x2, y2, x, y, current, o))
          current = [x, y]
        when "Z"
          ops.concat(_double_line(current[0], current[1], first[0], first[1], o))
          current = [first[0], first[1]]
        end
      end
      OpSet.new(type: :path, ops: ops)
    end

    # Fills

    def solid_fill_polygon(polygon_list, o)
      ops = []
      polygon_list.each do |points|
        next unless points.length > 0
        offset = o.max_randomness_offset || 0
        if points.length > 2
          ops << Op.new(op: :move, data: [points[0][0] + _offset_opt(offset, o), points[0][1] + _offset_opt(offset, o)])
          (1...points.length).each do |i|
            ops << Op.new(op: :lineTo, data: [points[i][0] + _offset_opt(offset, o), points[i][1] + _offset_opt(offset, o)])
          end
        end
      end
      OpSet.new(type: :fillPath, ops: ops)
    end

    def pattern_fill_polygons(polygon_list, o)
      require_relative "fillers/registry"
      Fillers.get(o, helper).fill_polygons(polygon_list, o)
    end

    def pattern_fill_arc(x, y, width, height, start, stop, o)
      cx = x
      cy = y
      rx = (width / 2.0).abs
      ry = (height / 2.0).abs
      rx += _offset_opt(rx * 0.01, o)
      ry += _offset_opt(ry * 0.01, o)
      strt = start
      stp = stop
      while strt < 0
        strt += Math::PI * 2
        stp += Math::PI * 2
      end
      if (stp - strt) > (Math::PI * 2)
        strt = 0
        stp = Math::PI * 2
      end
      increment = (stp - strt) / o.curve_step_count
      points = []
      angle = strt
      while angle <= stp
        points << [cx + rx * Math.cos(angle), cy + ry * Math.sin(angle)]
        angle += increment
      end
      points << [cx + rx * Math.cos(stp), cy + ry * Math.sin(stp)]
      points << [cx, cy]
      pattern_fill_polygons([points], o)
    end

    def rand_offset(x, o)
      _offset_opt(x, o)
    end

    def rand_offset_with_range(min, max, o)
      _offset(min, max, o)
    end

    def double_line_fill_ops(x1, y1, x2, y2, o)
      _double_line(x1, y1, x2, y2, o, true)
    end

    def helper
      @helper ||= RenderHelper.new
    end

    # RenderHelper passed to fillers
    class RenderHelper
      def rand_offset(x, o)
        Renderer._offset_opt(x, o)
      end

      def rand_offset_with_range(min, max, o)
        Renderer._offset(min, max, o)
      end

      def ellipse(x, y, width, height, o)
        Renderer.ellipse(x, y, width, height, o)
      end

      def double_line_ops(x1, y1, x2, y2, o)
        Renderer.double_line_fill_ops(x1, y1, x2, y2, o)
      end
    end

    # Internal methods (public for RenderHelper access)

    def self._random(ops)
      unless ops.randomizer
        ops.randomizer = Random.new(ops.seed || 0)
      end
      ops.randomizer.next
    end

    def self._offset(min, max, ops, roughness_gain = 1)
      ops.roughness * roughness_gain * ((_random(ops) * (max - min)) + min)
    end

    def self._offset_opt(x, ops, roughness_gain = 1)
      _offset(-x, x, ops, roughness_gain)
    end

    # Private methods

    def self.clone_options_alter_seed(ops)
      result = ops.dup
      result.randomizer = nil
      result.seed = ops.seed + 1 if ops.seed && ops.seed != 0
      result
    end

    def self._double_line(x1, y1, x2, y2, o, filling = false)
      single_stroke = filling ? o.disable_multi_stroke_fill : o.disable_multi_stroke
      o1 = _line_ops(x1, y1, x2, y2, o, true, false)
      return o1 if single_stroke
      o2 = _line_ops(x1, y1, x2, y2, o, true, true)
      o1 + o2
    end

    def self._line_ops(x1, y1, x2, y2, o, move, overlay)
      length_sq = (x1 - x2)**2 + (y1 - y2)**2
      length = Math.sqrt(length_sq)
      roughness_gain = if length < 200
        1
      elsif length > 500
        0.4
      else
        -0.0016668 * length + 1.233334
      end

      offset = o.max_randomness_offset || 0
      if (offset * offset * 100) > length_sq
        offset = length / 10.0
      end
      half_offset = offset / 2.0
      diverge_point = 0.2 + _random(o) * 0.2
      mid_disp_x = o.bowing * o.max_randomness_offset * (y2 - y1) / 200.0
      mid_disp_y = o.bowing * o.max_randomness_offset * (x1 - x2) / 200.0
      mid_disp_x = _offset_opt(mid_disp_x, o, roughness_gain)
      mid_disp_y = _offset_opt(mid_disp_y, o, roughness_gain)
      ops = []
      random_half = -> { _offset_opt(half_offset, o, roughness_gain) }
      random_full = -> { _offset_opt(offset, o, roughness_gain) }
      preserve_vertices = o.preserve_vertices

      if move
        ops << if overlay
          Op.new(op: :move, data: [
            x1 + (preserve_vertices ? 0 : random_half.call),
            y1 + (preserve_vertices ? 0 : random_half.call)
          ])
        else
          Op.new(op: :move, data: [
            x1 + (preserve_vertices ? 0 : _offset_opt(offset, o, roughness_gain)),
            y1 + (preserve_vertices ? 0 : _offset_opt(offset, o, roughness_gain))
          ])
        end
      end

      ops << if overlay
        Op.new(op: :bcurveTo, data: [
          mid_disp_x + x1 + (x2 - x1) * diverge_point + random_half.call,
          mid_disp_y + y1 + (y2 - y1) * diverge_point + random_half.call,
          mid_disp_x + x1 + 2 * (x2 - x1) * diverge_point + random_half.call,
          mid_disp_y + y1 + 2 * (y2 - y1) * diverge_point + random_half.call,
          x2 + (preserve_vertices ? 0 : random_half.call),
          y2 + (preserve_vertices ? 0 : random_half.call)
        ])
      else
        Op.new(op: :bcurveTo, data: [
          mid_disp_x + x1 + (x2 - x1) * diverge_point + random_full.call,
          mid_disp_y + y1 + (y2 - y1) * diverge_point + random_full.call,
          mid_disp_x + x1 + 2 * (x2 - x1) * diverge_point + random_full.call,
          mid_disp_y + y1 + 2 * (y2 - y1) * diverge_point + random_full.call,
          x2 + (preserve_vertices ? 0 : random_full.call),
          y2 + (preserve_vertices ? 0 : random_full.call)
        ])
      end
      ops
    end

    def self._curve_with_offset(points, offset, o)
      return [] if points.empty?
      ps = []
      ps << [points[0][0] + _offset_opt(offset, o), points[0][1] + _offset_opt(offset, o)]
      ps << [points[0][0] + _offset_opt(offset, o), points[0][1] + _offset_opt(offset, o)]
      (1...points.length).each do |i|
        ps << [points[i][0] + _offset_opt(offset, o), points[i][1] + _offset_opt(offset, o)]
        if i == points.length - 1
          ps << [points[i][0] + _offset_opt(offset, o), points[i][1] + _offset_opt(offset, o)]
        end
      end
      _curve_ops(ps, nil, o)
    end

    def self._curve_ops(points, close_point, o)
      len = points.length
      ops = []
      if len > 3
        s = 1 - o.curve_tightness
        ops << Op.new(op: :move, data: [points[1][0], points[1][1]])
        i = 1
        while (i + 2) < len
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
          ops << Op.new(op: :bcurveTo, data: [b1[0], b1[1], b2[0], b2[1], b3[0], b3[1]])
          i += 1
        end
        if close_point && close_point.length == 2
          ro = o.max_randomness_offset
          ops << Op.new(op: :lineTo, data: [close_point[0] + _offset_opt(ro, o), close_point[1] + _offset_opt(ro, o)])
        end
      elsif len == 3
        ops << Op.new(op: :move, data: [points[1][0], points[1][1]])
        ops << Op.new(op: :bcurveTo, data: [
          points[1][0], points[1][1], points[2][0], points[2][1], points[2][0], points[2][1]
        ])
      elsif len == 2
        ops.concat(_line_ops(points[0][0], points[0][1], points[1][0], points[1][1], o, true, true))
      end
      ops
    end

    def self._compute_ellipse_points(increment, cx, cy, rx, ry, offset, overlap, o)
      core_only = o.roughness == 0
      core_points = []
      all_points = []

      if core_only
        increment /= 4.0
        all_points << [cx + rx * Math.cos(-increment), cy + ry * Math.sin(-increment)]
        angle = 0.0
        while angle <= Math::PI * 2
          p = [cx + rx * Math.cos(angle), cy + ry * Math.sin(angle)]
          core_points << p
          all_points << p
          angle += increment
        end
        all_points << [cx + rx * Math.cos(0), cy + ry * Math.sin(0)]
        all_points << [cx + rx * Math.cos(increment), cy + ry * Math.sin(increment)]
      else
        rad_offset = _offset_opt(0.5, o) - (Math::PI / 2)
        all_points << [
          _offset_opt(offset, o) + cx + 0.9 * rx * Math.cos(rad_offset - increment),
          _offset_opt(offset, o) + cy + 0.9 * ry * Math.sin(rad_offset - increment)
        ]
        end_angle = Math::PI * 2 + rad_offset - 0.01
        angle = rad_offset
        while angle < end_angle
          p = [
            _offset_opt(offset, o) + cx + rx * Math.cos(angle),
            _offset_opt(offset, o) + cy + ry * Math.sin(angle)
          ]
          core_points << p
          all_points << p
          angle += increment
        end
        all_points << [
          _offset_opt(offset, o) + cx + rx * Math.cos(rad_offset + Math::PI * 2 + overlap * 0.5),
          _offset_opt(offset, o) + cy + ry * Math.sin(rad_offset + Math::PI * 2 + overlap * 0.5)
        ]
        all_points << [
          _offset_opt(offset, o) + cx + 0.98 * rx * Math.cos(rad_offset + overlap),
          _offset_opt(offset, o) + cy + 0.98 * ry * Math.sin(rad_offset + overlap)
        ]
        all_points << [
          _offset_opt(offset, o) + cx + 0.9 * rx * Math.cos(rad_offset + overlap * 0.5),
          _offset_opt(offset, o) + cy + 0.9 * ry * Math.sin(rad_offset + overlap * 0.5)
        ]
      end

      [all_points, core_points]
    end

    def self._arc(increment, cx, cy, rx, ry, strt, stp, offset, o)
      rad_offset = strt + _offset_opt(0.1, o)
      points = []
      points << [
        _offset_opt(offset, o) + cx + 0.9 * rx * Math.cos(rad_offset - increment),
        _offset_opt(offset, o) + cy + 0.9 * ry * Math.sin(rad_offset - increment)
      ]
      angle = rad_offset
      while angle <= stp
        points << [
          _offset_opt(offset, o) + cx + rx * Math.cos(angle),
          _offset_opt(offset, o) + cy + ry * Math.sin(angle)
        ]
        angle += increment
      end
      points << [cx + rx * Math.cos(stp), cy + ry * Math.sin(stp)]
      points << [cx + rx * Math.cos(stp), cy + ry * Math.sin(stp)]
      _curve_ops(points, nil, o)
    end

    def self._bezier_to(x1, y1, x2, y2, x, y, current, o)
      ops = []
      ros = [o.max_randomness_offset || 1, (o.max_randomness_offset || 1) + 0.3]
      iterations = o.disable_multi_stroke ? 1 : 2
      preserve_vertices = o.preserve_vertices
      iterations.times do |i|
        ops << if i == 0
          Op.new(op: :move, data: [current[0], current[1]])
        else
          Op.new(op: :move, data: [
            current[0] + (preserve_vertices ? 0 : _offset_opt(ros[0], o)),
            current[1] + (preserve_vertices ? 0 : _offset_opt(ros[0], o))
          ])
        end
        f = preserve_vertices ? [x, y] : [x + _offset_opt(ros[i], o), y + _offset_opt(ros[i], o)]
        ops << Op.new(op: :bcurveTo, data: [
          x1 + _offset_opt(ros[i], o), y1 + _offset_opt(ros[i], o),
          x2 + _offset_opt(ros[i], o), y2 + _offset_opt(ros[i], o),
          f[0], f[1]
        ])
      end
      ops
    end

    private_class_method :clone_options_alter_seed, :_double_line, :_line_ops,
      :_curve_with_offset, :_curve_ops, :_compute_ellipse_points,
      :_arc, :_bezier_to
  end
end
