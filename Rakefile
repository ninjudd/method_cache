require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rdoc/task'

Rake::TestTask.new do |t|
	t.libs << 'lib'
	t.libs << 'test'
	t.test_files = FileList['test/**/*_test.rb']
end

RDoc::Task.new do |rdoc|
	rdoc.rdoc_dir = 'rdoc'
	rdoc.title = 'method_cache'
	rdoc.options << '--line-numbers' << '--inline-source'
	rdoc.rdoc_files.include('README*')
	rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
	require 'rcov/rcovtask'
	Rcov::RcovTask.new do |t|
		t.libs << 'test'
		t.test_files = FileList['test/**/*_test.rb']
		t.verbose = true
	end
rescue LoadError
end

task :default => :test
