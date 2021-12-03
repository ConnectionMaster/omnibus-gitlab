#
# Copyright:: Copyright (c) 2017 GitLab Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
account_helper = AccountHelper.new(node)
omnibus_helper = OmnibusHelper.new(node)

working_dir = node['gitaly']['dir']
log_directory = node['gitaly']['log_directory']
env_directory = node['gitaly']['env_directory']
config_path = File.join(working_dir, "config.toml")
gitaly_path = node['gitaly']['bin_path']
wrapper_path = "#{gitaly_path}-wrapper"
pid_file = File.join(working_dir, "gitaly.pid")
json_logging = node['gitaly']['logging_format'].eql?('json')
open_files_ulimit = node['gitaly']['open_files_ulimit']
internal_socket_directory = node['gitaly']['internal_socket_dir']
cgroups_mountpoint = node['gitaly']['cgroups_mountpoint']
cgroups_hierarchy_root = node['gitaly']['cgroups_hierarchy_root']

directory working_dir do
  owner account_helper.gitlab_user
  mode '0700'
  recursive true
end

directory log_directory do
  owner account_helper.gitlab_user
  mode '0700'
  recursive true
end

directory internal_socket_directory do
  owner account_helper.gitlab_user
  mode '0700'
  recursive true
end

if cgroups_mountpoint && cgroups_hierarchy_root
  %w(cpu memory).each do |resource|
    directory File.join(cgroups_mountpoint, resource, cgroups_hierarchy_root) do
      owner account_helper.gitlab_user
      mode '0700'
    end
  end
end

# Doing this in attributes/default.rb will need gitlab cookbook to be loaded
# before gitaly cookbook. This means gitaly cookbook has to depend on gitlab
# cookbook.  Since gitlab cookbook already depends on gitaly cookbook, this
# causes a circular dependency. To avoid it, the default value is set in the
# recipe itself.
node.default['gitaly']['env'] = {
  'HOME' => node['gitlab']['user']['home'],
  'PATH' => "#{node['package']['install-dir']}/bin:#{node['package']['install-dir']}/embedded/bin:/bin:/usr/bin",
  'TZ' => ':/etc/localtime',
  # This is needed by gitlab-markup to import Python docutils
  'PYTHONPATH' => "#{node['package']['install-dir']}/embedded/lib/python3.9/site-packages",
  # Charlock Holmes and libicu will report U_FILE_ACCESS_ERROR if this is not set to the right path
  # See https://gitlab.com/gitlab-org/gitlab-foss/issues/17415#note_13868167
  'ICU_DATA' => "#{node['package']['install-dir']}/embedded/share/icu/current",
  'SSL_CERT_DIR' => "#{node['package']['install-dir']}/embedded/ssl/certs/",
  # wrapper script parameters
  'GITALY_PID_FILE' => pid_file,
  'WRAPPER_JSON_LOGGING' => json_logging.to_s
}

env_dir env_directory do
  variables node['gitaly']['env']
  notifies :restart, "runit_service[gitaly]" if omnibus_helper.should_notify?('gitaly')
end

gitlab_url, gitlab_relative_path = WebServerHelper.internal_api_url(node)
custom_hooks_dir = node.dig('gitlab', 'gitlab-shell', 'custom_hooks_dir') || node.dig('gitaly', 'custom_hooks_dir')

template "Create Gitaly config.toml" do
  path config_path
  source "gitaly-config.toml.erb"
  owner "root"
  group account_helper.gitlab_group
  mode "0640"
  variables node['gitaly'].to_hash.merge(
    { gitlab_shell: node['gitlab']['gitlab-shell'].to_hash,
      gitlab_url: gitlab_url,
      gitlab_relative_path: gitlab_relative_path,
      custom_hooks_dir: custom_hooks_dir }
  )
  notifies :hup, "runit_service[gitaly]" if omnibus_helper.should_notify?('gitaly')
end

runit_service 'gitaly' do
  start_down node['gitaly']['ha']
  options({
    user: account_helper.gitlab_user,
    groupname: account_helper.gitlab_group,
    working_dir: working_dir,
    env_dir: env_directory,
    bin_path: gitaly_path,
    wrapper_path: wrapper_path,
    config_path: config_path,
    log_directory: log_directory,
    json_logging: json_logging,
    open_files_ulimit: open_files_ulimit
  }.merge(params))
  log_options node['gitlab']['logging'].to_hash.merge(node['gitaly'].to_hash)
end

if node['gitlab']['bootstrap']['enable']
  execute "/opt/gitlab/bin/gitlab-ctl start gitaly" do
    retries 20
  end
end

version_file 'Create version file for Gitaly' do
  version_file_path File.join(working_dir, 'VERSION')
  version_check_cmd "/opt/gitlab/embedded/bin/ruby -rdigest/sha2 -e 'puts %(sha256:) + Digest::SHA256.file(%(/opt/gitlab/embedded/bin/gitaly)).hexdigest'"
  notifies :hup, "runit_service[gitaly]"
end

# If a version of ruby changes restart gitaly-ruby
version_file 'Create Ruby version file for Gitaly' do
  version_file_path File.join(working_dir, 'RUBY_VERSION')
  version_check_cmd '/opt/gitlab/embedded/bin/ruby --version'
  notifies :hup, "runit_service[gitaly]"
end

consul_service node['gitaly']['consul_service_name'] do
  id 'gitaly'
  meta node['gitaly']['consul_service_meta']
  action Prometheus.service_discovery_action
  socket_address node['gitaly']['prometheus_listen_addr']
  reload_service false unless node['consul']['enable']
end
