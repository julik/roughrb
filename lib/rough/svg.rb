# frozen_string_literal: true

require_relative "generator"

module Rough
  class SVG
    attr_reader :generator

    def initialize(**config_options)
      @generator = Generator.new(**config_options)
    end

    def draw(drawable)
      sets = drawable.sets || []
      o = drawable.options || @generator.default_options
      precision = o.fixed_decimal_place_digits
      parts = []

      sets.each do |drawing|
        case drawing.type
        when :path
          attrs = {
            "d" => @generator.ops_to_path(drawing, precision),
            "stroke" => o.stroke,
            "stroke-width" => o.stroke_width.to_s,
            "fill" => "none"
          }
          if o.stroke_line_dash
            attrs["stroke-dasharray"] = o.stroke_line_dash.join(" ").strip
          end
          if o.stroke_line_dash_offset
            attrs["stroke-dashoffset"] = o.stroke_line_dash_offset.to_s
          end
          parts << _path_element(attrs)

        when :fillPath
          attrs = {
            "d" => @generator.ops_to_path(drawing, precision),
            "stroke" => "none",
            "stroke-width" => "0",
            "fill" => o.fill || ""
          }
          if drawable.shape == "curve" || drawable.shape == "polygon"
            attrs["fill-rule"] = "evenodd"
          end
          parts << _path_element(attrs)

        when :fillSketch
          fweight = o.fill_weight
          fweight = o.stroke_width / 2.0 if fweight < 0
          attrs = {
            "d" => @generator.ops_to_path(drawing, precision),
            "stroke" => o.fill || "",
            "stroke-width" => fweight.to_s,
            "fill" => "none"
          }
          if o.fill_line_dash
            attrs["stroke-dasharray"] = o.fill_line_dash.join(" ").strip
          end
          if o.fill_line_dash_offset
            attrs["stroke-dashoffset"] = o.fill_line_dash_offset.to_s
          end
          parts << _path_element(attrs)
        end
      end

      "<g>#{parts.join}</g>"
    end

    # Convenience shape methods
    def line(x1, y1, x2, y2, **options)
      draw(@generator.line(x1, y1, x2, y2, **options))
    end

    def rectangle(x, y, width, height, **options)
      draw(@generator.rectangle(x, y, width, height, **options))
    end

    def ellipse(x, y, width, height, **options)
      draw(@generator.ellipse(x, y, width, height, **options))
    end

    def circle(x, y, diameter, **options)
      draw(@generator.circle(x, y, diameter, **options))
    end

    def linear_path(points, **options)
      draw(@generator.linear_path(points, **options))
    end

    def polygon(points, **options)
      draw(@generator.polygon(points, **options))
    end

    def arc(x, y, width, height, start, stop, closed: false, **options)
      draw(@generator.arc(x, y, width, height, start, stop, closed: closed, **options))
    end

    def curve(points, **options)
      draw(@generator.curve(points, **options))
    end

    def path(d, **options)
      draw(@generator.path(d, **options))
    end

    # Generate a complete SVG document
    def self.document(width, height, **options)
      svg = new(**options)
      content = yield svg
      %(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}">#{content}</svg>)
    end

    private

    def _path_element(attrs)
      attr_str = attrs.map { |k, v| "#{k}=\"#{_escape(v.to_s)}\"" }.join(" ")
      "<path #{attr_str}/>"
    end

    def _escape(s)
      s.gsub("&", "&amp;").gsub("\"", "&quot;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
