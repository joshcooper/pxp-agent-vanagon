project 'pxp-agent' do |proj|
  platform = proj.get_platform

  proj.version_from_git
  proj.generate_archives true
  proj.generate_packages false

  proj.description 'pxp-agent'
  proj.license 'See components'
  proj.vendor 'Puppet, Inc.  <info@puppet.com>'
  proj.homepage 'https://puppet.com'
  proj.identifier 'com.puppetlabs'

  # pxp-agent inherits most build settings from puppetlabs/puppet-runtime:
  # - Modifications to global settings like flags and target directories should be made in puppet-runtime.
  # - Settings included in this file should apply only to local components in this repository.
  runtime_details = JSON.parse(File.read('configs/components/puppet-runtime.json'))
  agent_branch = 'main'

  settings[:puppet_runtime_version] = runtime_details['version']
  settings[:puppet_runtime_location] = runtime_details['location']
  settings[:puppet_runtime_basename] = "agent-runtime-#{agent_branch}-#{runtime_details['version']}.#{platform.name}"

  settings_uri = File.join(runtime_details['location'], "#{proj.settings[:puppet_runtime_basename]}.settings.yaml")
  sha1sum_uri = "#{settings_uri}.sha1"
  metadata_uri = File.join(runtime_details['location'], "#{proj.settings[:puppet_runtime_basename]}.json")
  proj.inherit_yaml_settings(settings_uri, sha1sum_uri, metadata_uri: metadata_uri)

  proj.setting(:service_conf, File.join(proj.install_root, 'service_conf'))
  proj.setting(:chocolatey_lib, 'C:/ProgramData/chocolatey/lib') if platform.is_windows?

  proj.component 'pl-cmake-patch'
  proj.component 'puppet-runtime'
  proj.component 'runtime' if platform.name =~ /el-[67]|redhatfips-7|sles-1[12]|ubuntu-18.04-amd64/ || !platform.is_linux?

  proj.component 'leatherman'
  proj.component 'cpp-hocon'
  proj.component 'cpp-pcp-client'
  proj.component 'pxp-agent'
  proj.component 'nssm' if platform.is_windows?

  # remove unnecessary files
  proj.component 'cleanup'

  # what to include in package
  proj.directory proj.install_root
  proj.directory proj.prefix
  proj.directory proj.sysconfdir
  proj.directory proj.link_bindir
  proj.directory proj.service_conf

  proj.directory File.join(proj.sysconfdir, 'pxp-agent')
  if platform.is_windows?
    proj.directory File.join(proj.sysconfdir, 'pxp-agent', 'modules')
    proj.directory File.join(proj.install_root, 'pxp-agent', 'spool')
    proj.directory File.join(proj.install_root, 'pxp-agent', 'tasks-cache')
    proj.directory File.join(proj.sysconfdir, 'pxp-agent', 'log')
  else
    # Output directories (spool, tasks-cache, logdir) are restricted to root agent.
    # Modules is left readable so non-root agents can also use the installed modules.
    proj.directory File.join(proj.sysconfdir, 'pxp-agent', 'modules'), mode: '0755'
    proj.directory File.join(proj.install_root, 'pxp-agent', 'spool'), mode: '0750'
    proj.directory File.join(proj.install_root, 'pxp-agent', 'tasks-cache'), mode: '0750'
    proj.directory File.join(proj.logdir, 'pxp-agent'), mode: '0750'
  end

  proj.timeout 7200 if platform.is_windows?
end
