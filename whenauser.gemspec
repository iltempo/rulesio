# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'whenauser/version'

Gem::Specification.new do |s|
  s.name        = 'whenauser'
  s.version     = WhenAUser::VERSION
  s.authors     = ['David Anderson', 'Chris Weis']
  s.email       = ['david@alpinegizmo.com']
  s.homepage    = 'https://github.com/tractionlabs/whenauser'
  s.summary     = %q{Rack middleware for connecting to WhenAUser}
  s.description = %q{Rack middleware for connecting to WhenAUser}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_runtime_dependency 'activesupport'
  s.add_runtime_dependency 'actionpack'
  s.add_runtime_dependency 'faraday', '~> 0.8.0'
  s.add_runtime_dependency 'faraday_middleware'
end
