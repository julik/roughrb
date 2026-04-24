require "rake/testtask"
require "bundler/gem_tasks"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/**/test_*.rb"
end

task default: :test
