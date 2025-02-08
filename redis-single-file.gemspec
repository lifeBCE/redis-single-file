# frozen_string_literal: true

require_relative 'lib/redis_single_file/version'

Gem::Specification.new do |spec|
  spec.name    = 'redis-single-file'
  spec.version = RedisSingleFile::VERSION
  spec.authors = ['LifeBCE']
  spec.email   = ['eric06@gmail.com']

  spec.summary     = 'Distributed semaphore implementation with redis.'
  spec.description = 'Synchronize execution across numerous instances.'
  spec.homepage    = 'https://github.com/lifeBCE/redis-single-file'
  spec.license     = 'MIT'

  # Build Requiremenrs
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['changelog_uri'] = 'https://github.com/lifeBCE/redis-single-file/blob/main/CHANGELOG.md'

  # Local variables used when setting spec.files below
  gemspec  = File.basename(__FILE__)
  rejected = %w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]

  # NOTE: Grabs list of files to include in gem from git. New files/directories
  # will not be picked up until running 'git add' prior to building gem.
  #
  spec.files =
    IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
      # reject self and rejected paths defined above
      ls.readlines("\x0", chomp: true).reject do |f|
        (f == gemspec) || f.start_with?(*rejected)
      end
    end

  # Identify Gem Exectuables
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }

  # Redis Single File Dependencies
  spec.add_dependency 'redis', '~> 5.3.0'
  spec.add_dependency 'redis-clustering', '~> 5.3.0'

  # Disable MFA Requirement - github publishing can't support
  spec.metadata['rubygems_mfa_required'] = false

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
