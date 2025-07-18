source 'https://rubygems.org'

require_relative "lib/gitlab/version"

omnibus_gem_version = Gitlab::Version.new('omnibus')

# Note that omnibus is from a fork with additional gitlab changes.  You can
# check what they are with the following comparison link:

# https://gitlab.com/gitlab-org/omnibus/compare/v5.6.10...gitlab-omnibus-v5.6.10
#
# * Adds code to generate dependency_licenses.json
# * Modifies generation of #{install_dir}/LICENSE to be a combination of all
#   component licenses.

# When updating gem versions:
# 1. Edit this file to specify pinning if needed
# 2. `bundle update GEM`
# 3. Inspect and check-in Gemfile.lock
# 4. Check that the changes to Gemfile.lock are propogated to the software
#    definitions in `config/software`.  You can find them quickly with:
#      grep "gem 'install " config/software/*
gem 'omnibus', git: omnibus_gem_version.remote(Gitlab::Version::ALTERNATIVE_SOURCE), tag: omnibus_gem_version.print(false)
source 'https://packagecloud.io/cinc-project/stable' do
  gem 'chef', '~> 18.3.0'
  gem 'chef-cli', '~> 5.6.1'
  gem 'chef-utils'
  gem 'mixlib-versioning'
end
# Avoid the precompiled native gems because Omnibus specs need to run on older glibc versions.
gem 'ffi', '1.17.2', force_ruby_platform: true
gem 'unf_ext', '~>0.0.9.1'
gem 'ohai', '~> 18.0'
gem 'rainbow', '~> 2.2' # This is used by gitlab-ctl and the chef formatter
gem 'json'
gem 'rspec'
gem 'rake'
gem 'knapsack'
gem 'docker-api'
gem 'http'
gem 'aws-sdk-ec2'
gem 'aws-sdk-marketplacecatalog'
gem 'gitlab'
gem 'yard'
gem 'toml-rb'
gem 'retriable'
gem 'tomlib', '~> 0.6.0'
gem 'google-cloud-storage'

group :packagecloud, optional: true do
  gem 'package_cloud'
  gem 'thor', '~> 1.2'
end

group :danger, optional: true do
  gem 'gitlab-dangerfiles', '~> 4.9', require: false
end

group :rubocop do
  gem 'gitlab-styles', '~> 9.0', require: false
end

group :test do
  gem 'debug'
  gem 'chefspec', git: 'https://github.com/chef/chefspec' # Use git source because the last update to Rubygems was in July 2024.
  gem 'omnibus-ctl', '0.3.6'
  gem 'fantaskspec'
  gem 'rspec_junit_formatter'
  gem 'rspec-parameterized', require: false
  gem 'simplecov-cobertura'
end
