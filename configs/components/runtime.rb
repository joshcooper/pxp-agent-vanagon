component 'runtime' do |pkg, _settings, platform|
  if platform.is_cross_compiled_linux? || platform.name =~ /solaris-11/
    pkg.build_requires "pl-binutils-#{platform.architecture}"
    pkg.build_requires "pl-gcc-#{platform.architecture}"
    pkg.build_requires "pl-binutils-#{platform.architecture}"
  elsif platform.is_aix?
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-gcc-5.2.0-11.aix#{platform.os_version}.ppc.rpm"
  elsif platform.is_windows?
    pkg.build_requires "pl-gdbm-#{platform.architecture}"
    pkg.build_requires "pl-iconv-#{platform.architecture}"
    pkg.build_requires "pl-libffi-#{platform.architecture}"
    pkg.build_requires "pl-pdcurses-#{platform.architecture}"
  elsif platform.name =~ /el-[67]|redhatfips-7|sles-1[12]|ubuntu-18.04-amd64/
    pkg.build_requires 'pl-gcc'
  end
end
