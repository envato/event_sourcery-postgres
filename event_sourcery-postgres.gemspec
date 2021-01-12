# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'event_sourcery/postgres/version'

Gem::Specification.new do |spec|
  spec.name          = 'event_sourcery-postgres'
  spec.version       = EventSourcery::Postgres::VERSION

  spec.authors       = ['Envato']
  spec.email         = ['rubygems@envato.com']

  spec.summary       = 'Postgres event store for use with EventSourcery'
  spec.homepage      = 'https://github.com/envato/event_sourcery-postgres'
  spec.metadata      = {
                         'bug_tracker_uri' => 'https://github.com/envato/event_sourcery-postgres/issues',
                         'changelog_uri'   => 'https://github.com/envato/event_sourcery-postgres/blob/HEAD/CHANGELOG.md',
                         'source_code_uri' => 'https://github.com/envato/event_sourcery-postgres',
                       }

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(\.|bin/|Gemfile|Rakefile|script/|spec/)})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.2.0'

  spec.add_dependency 'sequel', '>= 4.38'
  spec.add_dependency 'pg'
  spec.add_dependency 'event_sourcery', '>= 0.14.0'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake', '~> 13'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'benchmark-ips'
end
