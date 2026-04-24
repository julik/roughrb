#!/usr/bin/env ruby
# Generate SVG files for all README examples.
# Run: ruby -Ilib test/generate_readme_examples.rb
# Then: qlmanage -p test/fixtures/visual/readme_*.svg

require "rough"
require "fileutils"

OUT = File.join(__dir__, "fixtures", "visual")
FileUtils.mkdir_p(OUT)

def write_svg(name, width, height, &block)
  doc = Rough::SVG.document(width, height, &block)
  path = File.join(OUT, "readme_#{name}.svg")
  File.write(path, doc)
  puts "  #{path} (#{doc.length} bytes)"
end

puts "Generating README example SVGs..."

# Basic rectangle
write_svg("01_rectangle", 400, 240) do |svg|
  svg.rectangle(10, 10, 200, 200, seed: 42)
end

# Lines and ellipses
write_svg("02_lines_ellipses", 450, 200) do |svg|
  svg.circle(80, 120, 50, seed: 42) +
    svg.ellipse(300, 100, 150, 80, seed: 42) +
    svg.line(80, 120, 300, 100, seed: 42)
end

# Filling
write_svg("03_filling", 320, 220) do |svg|
  svg.circle(50, 50, 80, seed: 1, fill: "red") +
    svg.rectangle(120, 15, 80, 80, seed: 1, fill: "red") +
    svg.circle(50, 150, 80, seed: 1,
      fill: "rgb(10,150,10)",
      fill_weight: 3) +
    svg.rectangle(220, 15, 80, 80, seed: 1,
      fill: "red",
      hachure_angle: 60,
      hachure_gap: 8) +
    svg.rectangle(120, 105, 80, 80, seed: 1,
      fill: "rgba(255,0,200,0.2)",
      fill_style: "solid")
end

# Fill styles showcase
write_svg("04_fill_styles", 600, 120) do |svg|
  styles = %w[hachure solid zigzag cross-hatch dots dashed zigzag-line]
  styles.map.with_index do |style, i|
    svg.rectangle(10 + i * 82, 10, 70, 70, seed: 42, fill: "steelblue", fill_style: style)
  end.join
end

# Sketching style
write_svg("05_sketching_style", 320, 120) do |svg|
  svg.rectangle(15, 15, 80, 80, seed: 1, roughness: 0.5, fill: "red") +
    svg.rectangle(120, 15, 80, 80, seed: 1, roughness: 2.8, fill: "blue") +
    svg.rectangle(220, 15, 80, 80, seed: 1, bowing: 6, stroke: "green", stroke_width: 3)
end

# SVG paths
write_svg("06_svg_paths", 350, 320) do |svg|
  svg.path("M80 80 A 45 45, 0, 0, 0, 125 125 L 125 80 Z", seed: 1, fill: "green") +
    svg.path("M230 80 A 45 45, 0, 1, 0, 275 125 L 275 80 Z", seed: 1, fill: "purple") +
    svg.path("M80 230 A 45 45, 0, 0, 1, 125 275 L 125 230 Z", seed: 1, fill: "red") +
    svg.path("M230 230 A 45 45, 0, 1, 1, 275 275 L 275 230 Z", seed: 1, fill: "blue")
end

# Curves
write_svg("07_curves", 400, 200) do |svg|
  svg.curve([[10, 100], [100, 10], [200, 100], [300, 10], [390, 100]], seed: 42) +
    svg.curve([[10, 150], [100, 190], [200, 130], [300, 190], [390, 150]], seed: 42, fill: "coral")
end

# Polygons
write_svg("08_polygons", 400, 200) do |svg|
  svg.polygon([[50, 10], [150, 10], [180, 80], [100, 150], [20, 80]], seed: 42, fill: "khaki") +
    svg.polygon([[250, 20], [350, 50], [370, 150], [280, 180], [220, 100]], seed: 42, fill: "lavender", fill_style: "cross-hatch")
end

# Arc
write_svg("09_arcs", 400, 200) do |svg|
  svg.arc(100, 100, 150, 150, 0, Math::PI, closed: true, seed: 42, fill: "tomato") +
    svg.arc(300, 100, 150, 150, Math::PI, Math::PI * 2, closed: true, seed: 42, fill: "dodgerblue")
end

# Full composition
write_svg("10_composition", 500, 350) do |svg|
  # Sky
  svg.rectangle(0, 0, 500, 200, seed: 10, fill: "lightskyblue", fill_style: "solid", stroke: "none") +
    # Ground
    svg.rectangle(0, 200, 500, 150, seed: 11, fill: "olivedrab", fill_style: "solid", stroke: "none") +
    # House body
    svg.rectangle(150, 120, 200, 150, seed: 42, fill: "burlywood", stroke_width: 2) +
    # Roof
    svg.polygon([[140, 120], [250, 40], [360, 120]], seed: 42, fill: "firebrick", stroke_width: 2) +
    # Door
    svg.rectangle(220, 190, 60, 80, seed: 42, fill: "saddlebrown") +
    # Windows
    svg.rectangle(170, 160, 40, 40, seed: 42, fill: "lightyellow") +
    svg.rectangle(290, 160, 40, 40, seed: 42, fill: "lightyellow") +
    # Sun
    svg.circle(430, 60, 60, seed: 42, fill: "gold") +
    # Tree trunk
    svg.rectangle(60, 180, 20, 70, seed: 42, fill: "saddlebrown") +
    # Tree canopy
    svg.circle(70, 160, 70, seed: 42, fill: "forestgreen")
end

puts "Done! Preview with:"
puts "  qlmanage -p #{OUT}/readme_*.svg"
