require "bundler"
require "bundler/gem_tasks"
Bundler::GemHelper.install_tasks
Bundler.setup

require "rake/testtask"
Rake::TestTask.new(:test) do |test|
  test.libs = %w(lib test)
  test.pattern = "test/**/test_*.rb"
  test.verbose = true
end

task :default => :test
