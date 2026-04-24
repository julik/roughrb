module Rough
  module PathDataParser
    Segment = Struct.new(:key, :data, keyword_init: true)

    PARAMS = {
      "A" => 7, "a" => 7, "C" => 6, "c" => 6, "H" => 1, "h" => 1,
      "L" => 2, "l" => 2, "M" => 2, "m" => 2, "Q" => 4, "q" => 4,
      "S" => 4, "s" => 4, "T" => 2, "t" => 2, "V" => 1, "v" => 1,
      "Z" => 0, "z" => 0
    }.freeze

    COMMAND_RE = /\A[aAcChHlLmMqQsStTvVzZ]/
    NUMBER_RE = /\A([-+]?[0-9]+(\.[0-9]*)?|[-+]?\.[0-9]+)([eE][-+]?[0-9]+)?/
    WHITESPACE_RE = /\A[ \t\r\n,]+/

    module_function

    def parse(d)
      tokens = tokenize(d)
      segments = []
      mode = "BOD"
      index = 0

      while index < tokens.length && tokens[index][:type] != :eod
        token = tokens[index]
        params_count = 0
        params = []

        if mode == "BOD"
          if token[:text] == "M" || token[:text] == "m"
            index += 1
            params_count = PARAMS[token[:text]]
            mode = token[:text]
          else
            return parse("M0,0" + d)
          end
        elsif token[:type] == :number
          params_count = PARAMS[mode]
        else
          index += 1
          params_count = PARAMS[token[:text]]
          mode = token[:text]
        end

        if (index + params_count) < tokens.length
          params_count.times do |i|
            num_token = tokens[index + i]
            if num_token[:type] == :number
              params << num_token[:text].to_f
            else
              raise "Param not a number: #{mode},#{num_token[:text]}"
            end
          end

          if PARAMS.key?(mode)
            segments << Segment.new(key: mode, data: params)
            index += params_count
            mode = "L" if mode == "M"
            mode = "l" if mode == "m"
          else
            raise "Bad segment: #{mode}"
          end
        else
          raise "Path data ended short"
        end
      end

      segments
    end

    def absolutize(segments)
      cx = 0.0
      cy = 0.0
      subx = 0.0
      suby = 0.0
      out = []

      segments.each do |seg|
        key = seg.key
        data = seg.data

        case key
        when "M"
          out << Segment.new(key: "M", data: data.dup)
          cx, cy = data
          subx, suby = data
        when "m"
          cx += data[0]
          cy += data[1]
          out << Segment.new(key: "M", data: [cx, cy])
          subx = cx
          suby = cy
        when "L"
          out << Segment.new(key: "L", data: data.dup)
          cx, cy = data
        when "l"
          cx += data[0]
          cy += data[1]
          out << Segment.new(key: "L", data: [cx, cy])
        when "C"
          out << Segment.new(key: "C", data: data.dup)
          cx = data[4]
          cy = data[5]
        when "c"
          newdata = data.each_with_index.map { |d, i| i.odd? ? d + cy : d + cx }
          out << Segment.new(key: "C", data: newdata)
          cx = newdata[4]
          cy = newdata[5]
        when "Q"
          out << Segment.new(key: "Q", data: data.dup)
          cx = data[2]
          cy = data[3]
        when "q"
          newdata = data.each_with_index.map { |d, i| i.odd? ? d + cy : d + cx }
          out << Segment.new(key: "Q", data: newdata)
          cx = newdata[2]
          cy = newdata[3]
        when "A"
          out << Segment.new(key: "A", data: data.dup)
          cx = data[5]
          cy = data[6]
        when "a"
          cx += data[5]
          cy += data[6]
          out << Segment.new(key: "A", data: [data[0], data[1], data[2], data[3], data[4], cx, cy])
        when "H"
          out << Segment.new(key: "H", data: data.dup)
          cx = data[0]
        when "h"
          cx += data[0]
          out << Segment.new(key: "H", data: [cx])
        when "V"
          out << Segment.new(key: "V", data: data.dup)
          cy = data[0]
        when "v"
          cy += data[0]
          out << Segment.new(key: "V", data: [cy])
        when "S"
          out << Segment.new(key: "S", data: data.dup)
          cx = data[2]
          cy = data[3]
        when "s"
          newdata = data.each_with_index.map { |d, i| i.odd? ? d + cy : d + cx }
          out << Segment.new(key: "S", data: newdata)
          cx = newdata[2]
          cy = newdata[3]
        when "T"
          out << Segment.new(key: "T", data: data.dup)
          cx = data[0]
          cy = data[1]
        when "t"
          cx += data[0]
          cy += data[1]
          out << Segment.new(key: "T", data: [cx, cy])
        when "Z", "z"
          out << Segment.new(key: "Z", data: [])
          cx = subx
          cy = suby
        end
      end

      out
    end

    def normalize(segments)
      out = []
      last_type = ""
      cx = 0.0
      cy = 0.0
      subx = 0.0
      suby = 0.0
      lcx = 0.0
      lcy = 0.0

      segments.each do |seg|
        key = seg.key
        data = seg.data

        case key
        when "M"
          out << Segment.new(key: "M", data: data.dup)
          cx, cy = data
          subx, suby = data
        when "C"
          out << Segment.new(key: "C", data: data.dup)
          cx = data[4]
          cy = data[5]
          lcx = data[2]
          lcy = data[3]
        when "L"
          out << Segment.new(key: "L", data: data.dup)
          cx, cy = data
        when "H"
          cx = data[0]
          out << Segment.new(key: "L", data: [cx, cy])
        when "V"
          cy = data[0]
          out << Segment.new(key: "L", data: [cx, cy])
        when "S"
          if last_type == "C" || last_type == "S"
            cx1 = cx + (cx - lcx)
            cy1 = cy + (cy - lcy)
          else
            cx1 = cx
            cy1 = cy
          end
          out << Segment.new(key: "C", data: [cx1, cy1, *data])
          lcx = data[0]
          lcy = data[1]
          cx = data[2]
          cy = data[3]
        when "T"
          x, y = data
          if last_type == "Q" || last_type == "T"
            x1 = cx + (cx - lcx)
            y1 = cy + (cy - lcy)
          else
            x1 = cx
            y1 = cy
          end
          cx1 = cx + 2.0 * (x1 - cx) / 3.0
          cy1 = cy + 2.0 * (y1 - cy) / 3.0
          cx2 = x + 2.0 * (x1 - x) / 3.0
          cy2 = y + 2.0 * (y1 - y) / 3.0
          out << Segment.new(key: "C", data: [cx1, cy1, cx2, cy2, x, y])
          lcx = x1
          lcy = y1
          cx = x
          cy = y
        when "Q"
          x1, y1, x, y = data
          cx1 = cx + 2.0 * (x1 - cx) / 3.0
          cy1 = cy + 2.0 * (y1 - cy) / 3.0
          cx2 = x + 2.0 * (x1 - x) / 3.0
          cy2 = y + 2.0 * (y1 - y) / 3.0
          out << Segment.new(key: "C", data: [cx1, cy1, cx2, cy2, x, y])
          lcx = x1
          lcy = y1
          cx = x
          cy = y
        when "A"
          r1 = data[0].abs
          r2 = data[1].abs
          angle = data[2]
          large_arc_flag = data[3]
          sweep_flag = data[4]
          x = data[5]
          y = data[6]
          if r1 == 0 || r2 == 0
            out << Segment.new(key: "C", data: [cx, cy, x, y, x, y])
            cx = x
            cy = y
          elsif cx != x || cy != y
            curves = arc_to_cubic_curves(cx, cy, x, y, r1, r2, angle, large_arc_flag, sweep_flag)
            curves.each { |c| out << Segment.new(key: "C", data: c) }
            cx = x
            cy = y
          end
        when "Z"
          out << Segment.new(key: "Z", data: [])
          cx = subx
          cy = suby
        end

        last_type = key
      end

      out
    end

    def serialize(segments)
      tokens = []
      segments.each do |seg|
        tokens << seg.key
        case seg.key
        when "C", "c"
          tokens << seg.data[0] << "#{seg.data[1]}," << seg.data[2] << "#{seg.data[3]}," << seg.data[4] << seg.data[5]
        when "S", "s", "Q", "q"
          tokens << seg.data[0] << "#{seg.data[1]}," << seg.data[2] << seg.data[3]
        else
          tokens.concat(seg.data)
        end
      end
      tokens.join(" ")
    end

    # Private helpers

    def self.tokenize(d)
      tokens = []
      while !d.empty?
        if (m = d.match(WHITESPACE_RE))
          d = d[m[0].length..]
        elsif (m = d.match(COMMAND_RE))
          tokens << {type: :command, text: m[0]}
          d = d[m[0].length..]
        elsif (m = d.match(NUMBER_RE))
          tokens << {type: :number, text: m[0].to_f.to_s}
          d = d[m[0].length..]
        else
          return []
        end
      end
      tokens << {type: :eod, text: ""}
      tokens
    end

    def self.deg_to_rad(degrees)
      Math::PI * degrees / 180.0
    end

    def self.rotate(x, y, angle_rad)
      xx = x * Math.cos(angle_rad) - y * Math.sin(angle_rad)
      yy = x * Math.sin(angle_rad) + y * Math.cos(angle_rad)
      [xx, yy]
    end

    def self.arc_to_cubic_curves(x1, y1, x2, y2, r1, r2, angle, large_arc_flag, sweep_flag, recursive = nil)
      angle_rad = deg_to_rad(angle)
      params = []

      if recursive
        f1, f2, cx, cy = recursive
      else
        x1, y1 = rotate(x1, y1, -angle_rad)
        x2, y2 = rotate(x2, y2, -angle_rad)

        x = (x1 - x2) / 2.0
        y = (y1 - y2) / 2.0
        h = (x * x) / (r1 * r1) + (y * y) / (r2 * r2)
        if h > 1
          h = Math.sqrt(h)
          r1 = h * r1
          r2 = h * r2
        end

        sign = (large_arc_flag == sweep_flag) ? -1 : 1

        r1_pow = r1 * r1
        r2_pow = r2 * r2

        left = r1_pow * r2_pow - r1_pow * y * y - r2_pow * x * x
        right = r1_pow * y * y + r2_pow * x * x

        k = sign * Math.sqrt((left / right).abs)

        cx = k * r1 * y / r2 + (x1 + x2) / 2.0
        cy = k * -r2 * x / r1 + (y1 + y2) / 2.0

        f1 = Math.asin(((y1 - cy) / r2).round(9))
        f2 = Math.asin(((y2 - cy) / r2).round(9))

        f1 = Math::PI - f1 if x1 < cx
        f2 = Math::PI - f2 if x2 < cx

        f1 += Math::PI * 2 if f1 < 0
        f2 += Math::PI * 2 if f2 < 0

        if sweep_flag != 0 && f1 > f2
          f1 -= Math::PI * 2
        end
        if sweep_flag == 0 && f2 > f1
          f2 -= Math::PI * 2
        end
      end

      df = f2 - f1

      if df.abs > (Math::PI * 120 / 180)
        f2old = f2
        x2old = x2
        y2old = y2

        if sweep_flag != 0 && f2 > f1
          f2 = f1 + (Math::PI * 120 / 180)
        else
          f2 = f1 - (Math::PI * 120 / 180)
        end

        x2 = cx + r1 * Math.cos(f2)
        y2 = cy + r2 * Math.sin(f2)
        params = arc_to_cubic_curves(x2, y2, x2old, y2old, r1, r2, angle, 0, sweep_flag, [f2, f2old, cx, cy])
      end

      df = f2 - f1

      c1 = Math.cos(f1)
      s1 = Math.sin(f1)
      c2 = Math.cos(f2)
      s2 = Math.sin(f2)
      t = Math.tan(df / 4.0)
      hx = 4.0 / 3.0 * r1 * t
      hy = 4.0 / 3.0 * r2 * t

      m1 = [x1, y1]
      m2 = [x1 + hx * s1, y1 - hy * c1]
      m3 = [x2 + hx * s2, y2 - hy * c2]
      m4 = [x2, y2]

      m2[0] = 2 * m1[0] - m2[0]
      m2[1] = 2 * m1[1] - m2[1]

      if recursive
        [m2, m3, m4].concat(params)
      else
        params = [m2, m3, m4].concat(params)
        curves = []
        i = 0
        while i < params.length
          r1p = rotate(params[i][0], params[i][1], angle_rad)
          r2p = rotate(params[i + 1][0], params[i + 1][1], angle_rad)
          r3p = rotate(params[i + 2][0], params[i + 2][1], angle_rad)
          curves << [r1p[0], r1p[1], r2p[0], r2p[1], r3p[0], r3p[1]]
          i += 3
        end
        curves
      end
    end

    private_class_method :tokenize, :deg_to_rad, :rotate, :arc_to_cubic_curves
  end
end
