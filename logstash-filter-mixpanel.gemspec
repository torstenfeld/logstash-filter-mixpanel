Gem::Specification.new do |s|
  s.name = 'logstash-filter-mixpanel'
  s.version = '0.1.3'
  s.version = "#{s.version}.pre.#{ENV['TRAVIS_BUILD_NUMBER']}" if ENV['TRAVIS'] and ENV['TRAVIS_BRANCH'] != 'master'
  s.licenses = ['Apache License (2.0)']
  s.summary = "This filter checks mixpanel for additional people data and adds it to the event data"
  s.description = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install gemname. This gem is not a stand-alone program"
  s.authors = ["Torsten Feld"]
  s.email = 'logstash@torsten-feld.de'
  s.homepage = "https://github.com/torstenfeld/logstash-filter-mixpanel"
  s.require_paths = ["lib"]

  # Files
  s.files = `git ls-files`.split($\)
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "filter" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core", '>= 1.4.0', '< 2.0.0'
  s.add_runtime_dependency "mixpanel_client", '~> 4.1'
  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency 'coveralls', '~> 0.8'
  s.add_development_dependency 'ffaker', '~> 2.0'
  s.add_development_dependency 'mixpanel-ruby', '< 2.0'
end
