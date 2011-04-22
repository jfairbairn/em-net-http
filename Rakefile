require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "em-net-http"
    gem.summary = %Q{Non-blocking replacement for Net::HTTP, for use in EventMachine}
    gem.description = %Q{Monkeypatching Net::HTTP to use em-http-request under the hood.}
    gem.email = "james@netlagoon.com"
    gem.homepage = "http://github.com/jfairbairn/em-net-http"
    gem.authors = ["James Fairbairn"]
    gem.add_dependency 'eventmachine', '>= 0.12.10'
    gem.add_dependency 'addressable'
    gem.add_dependency 'em-http-request', '>= 0.2.10'
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_development_dependency "mimic", ">= 0.3.0"
    gem.add_development_dependency 'weary'
    gem.add_development_dependency 'right_aws'
    gem.add_development_dependency 'tumblr-rb'
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "em-net-http #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
