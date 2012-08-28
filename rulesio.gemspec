# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'rulesio/version'

Gem::Specification.new do |s|
  s.name        = 'rulesio'
  s.version     = RulesIO::VERSION
  s.authors     = ['David Anderson', 'Chris Weis']
  s.email       = ['david@alpinegizmo.com']
  s.homepage    = 'https://github.com/rulesio/rulesio'
  s.summary     = %q{Rack middleware for connecting to rules.io}
  s.description = %q{Rack middleware for connecting Rack applications to rules.io, with extensions for Rails 3 applications.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_runtime_dependency 'activesupport'
  s.add_runtime_dependency 'actionpack'
  s.add_runtime_dependency 'girl_friday', '~> 0.10.0'
end
