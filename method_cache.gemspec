Gem::Specification.new do |s|
  s.name = %q{method_cache}
  s.version = "0.6.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Justin Balthrop"]
  s.date = %q{2009-04-16}
  s.description = %q{Simple memcache-based memoization library for Ruby}
  s.email = %q{code@justinbalthrop.com}
  s.files = ["README.rdoc", "VERSION.yml", "lib/method_cache", "lib/method_cache/proxy.rb", "lib/method_cache.rb", "test/method_cache_test.rb", "test/test_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/ninjudd/method_cache}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{Simple memcache-based memoization library for Ruby}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
    else
    end
  else
  end
end
