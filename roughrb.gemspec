require_relative "lib/rough/version"

Gem::Specification.new do |s|
  s.name = "roughrb"
  s.version = Rough::VERSION
  s.summary = "Hand-drawn style SVG graphics"
  s.description = "Ruby port of rough.js - creates graphics with a hand-drawn, sketchy appearance. SVG output only."
  s.authors = ["Julik Tarkhanov"]
  s.license = "MIT"
  s.homepage = "https://github.com/julik/roughrb"
  s.required_ruby_version = ">= 3.0"
  s.files = Dir["lib/**/*.rb"] + ["LICENSE", "README.md"]
  s.require_paths = ["lib"]
end
