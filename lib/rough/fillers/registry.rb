require_relative "hachure"
require_relative "hatch"
require_relative "zigzag"
require_relative "zigzag_line"
require_relative "dashed"
require_relative "dot"

module Rough
  module Fillers
    @fillers = {}

    def self.get(o, helper)
      filler_name = o.fill_style || "hachure"
      @fillers[filler_name] ||= case filler_name
      when "zigzag"
        Zigzag.new(helper)
      when "cross-hatch"
        Hatch.new(helper)
      when "dots"
        Dot.new(helper)
      when "dashed"
        Dashed.new(helper)
      when "zigzag-line"
        ZigzagLine.new(helper)
      else
        Hachure.new(helper)
      end
    end
  end
end
