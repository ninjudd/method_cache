# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'method_cache/version'

Gem::Specification.new do |gem|
	gem.name = 'method_cache'
	gem.version = MethodCache::VERSION
	gem.authors = ['Justin Balthrop', 'Aaron Ten Clay']
	gem.email = ['git@justinbalthrop.com', 'aarontc@aarontc.com']
	gem.description = %q{Simple memcache-based memoization library for Ruby}
	gem.summary = gem.description
	gem.homepage = 'https://github.com/aarontc/method_cache'
	gem.license = 'MIT'

	gem.add_development_dependency 'shoulda'
	gem.add_development_dependency 'mocha'
	gem.add_development_dependency 'dalli'
	gem.add_development_dependency 'activesupport', '~> 2.3.9'
	gem.add_development_dependency 'bundler', '~> 1.10'
	gem.add_development_dependency 'rake', '~> 10.0'
	# gem.add_development_dependency "minitest"

	gem.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
	gem.bindir = 'exe'
	gem.executables = gem.files.grep(%r{^exe/}) { |f| File.basename(f) }
	gem.test_files = gem.files.grep(%r{^(test|spec|features)/})
	gem.require_paths = ['lib']
end
