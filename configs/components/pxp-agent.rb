component 'pxp-agent' do |pkg, settings, platform|
  pkg.load_from_json('configs/components/pxp-agent.json')

  toolchain = '-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/pl-build-toolchain.cmake'
  cmake = '/opt/pl-build-tools/bin/cmake'
  boost_static_flag = ''

  if platform.is_windows?
    pkg.environment 'PATH', "$(shell cygpath -u #{settings[:prefix]}/lib):$(shell cygpath -u #{settings[:gcc_bindir]}):$(shell cygpath -u #{settings[:ruby_bindir]}):/cygdrive/c/Windows/system32:/cygdrive/c/Windows:/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0"
  else
    pkg.environment 'PATH', "#{settings[:bindir]}:/opt/pl-build-tools/bin:$(PATH)"
  end

  if settings[:system_openssl]
    pkg.build_requires 'openssl-devel'
  else
    pkg.build_requires 'puppet-runtime' # Provides openssl
  end

  pkg.build_requires 'leatherman'
  pkg.build_requires 'cpp-pcp-client'
  pkg.build_requires 'cpp-hocon'

  make = platform[:make]

  special_flags = " -DCMAKE_INSTALL_PREFIX=#{settings[:prefix]} "

  if platform.is_aix?
  elsif platform.is_macos?
    cmake = '/usr/local/bin/cmake'
    toolchain = ''
    special_flags += "-DCMAKE_CXX_FLAGS='#{settings[:cflags]}' -DENABLE_CXX_WERROR=OFF"
    boost_static_flag = '-DBOOST_STATIC=OFF'
    if platform.is_cross_compiled?
      pkg.environment 'CXX', 'clang++ -target arm64-apple-macos11' if platform.name =~ /osx-11/
      pkg.environment 'CXX', 'clang++ -target arm64-apple-macos12' if platform.name =~ /osx-12/
    end
  elsif platform.is_cross_compiled_linux?
    cmake = '/opt/pl-build-tools/bin/cmake'
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/#{settings[:platform_triple]}/pl-build-toolchain.cmake"
  elsif platform.is_solaris?
    cmake = "/opt/pl-build-tools/i386-pc-solaris2.#{platform.os_version}/bin/cmake"
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/#{settings[:platform_triple]}/pl-build-toolchain.cmake"

    # PCP-87: If we build with -O3, solaris segfaults due to something in std::vector
    special_flags += " -DCMAKE_CXX_FLAGS_RELEASE='-O2 -DNDEBUG' "

    special_flags += if platform.name =~ /^solaris-10-sparc/
                       " -DCMAKE_EXE_LINKER_FLAGS=' /opt/puppetlabs/puppet/lib/libssl.so /opt/puppetlabs/puppet/lib/libgcc_s.so /opt/puppetlabs/puppet/lib/libcrypto.so' "
                     else
                       " -DCMAKE_EXE_LINKER_FLAGS=' /opt/puppetlabs/puppet/lib/libssl.so /opt/puppetlabs/puppet/lib/libcrypto.so' "
                     end

  elsif platform.is_windows?
    make = "#{settings[:gcc_bindir]}/mingw32-make"
    pkg.environment 'CYGWIN', settings[:cygwin]

    cmake = 'C:/ProgramData/chocolatey/bin/cmake.exe -G "MinGW Makefiles"'
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=#{settings[:tools_root]}/pl-build-toolchain.cmake"

  elsif platform.name =~ /el-[67]|redhatfips-7|sles-12|ubuntu-18.04-amd64/
    # use default that is pl-build-tools
  else
    # These platforms use the default OS toolchain, rather than pl-build-tools
    cmake = 'cmake'
    toolchain = ''
    special_flags += " -DCMAKE_CXX_FLAGS='#{settings[:cflags]} -Wno-deprecated -Wimplicit-fallthrough=0' "
    special_flags += ' -DENABLE_CXX_WERROR=OFF ' unless platform.name =~ /sles-15/
  end

  # Boost_NO_BOOST_CMAKE=ON was added while upgrading to boost
  # 1.73 for PA-3244. https://cmake.org/cmake/help/v3.0/module/FindBoost.html#boost-cmake
  # describes the setting itself (and what we are disabling). It
  # may make sense in the future to remove this cmake parameter and
  # actually make the boost build work with boost's own cmake
  # helpers. But for now disabling boost's cmake helpers allow us
  # to upgrade boost with minimal changes.
  #                                  - Sean P. McDonald 5/19/2020
  pkg.configure do
    [
      "#{cmake}\
      #{toolchain} \
          -DLEATHERMAN_GETTEXT=ON \
          -DCMAKE_VERBOSE_MAKEFILE=ON \
          -DCMAKE_PREFIX_PATH=#{settings[:prefix]} \
          -DCMAKE_INSTALL_RPATH=#{settings[:libdir]} \
          -DCMAKE_SYSTEM_PREFIX_PATH=#{settings[:prefix]} \
          -DMODULES_INSTALL_PATH=#{File.join(settings[:install_root], 'pxp-agent', 'modules')} \
          #{special_flags} \
          #{boost_static_flag} \
          -DBoost_NO_BOOST_CMAKE=ON \
          ."
    ]
  end

  pkg.build do
    ["#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1)"]
  end

  pkg.install do
    ["#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1) install"]
  end

  service_conf = settings[:service_conf]
  platform.get_service_types.each do |servicetype|
    case servicetype
    when 'systemd'
      pkg.install_file('ext/systemd/pxp-agent.service', "#{service_conf}/systemd/pxp-agent.service")
      pkg.install_file('ext/redhat/pxp-agent.sysconfig', "#{service_conf}/redhat/pxp-agent.sysconfig")
      pkg.install_file('ext/systemd/pxp-agent.logrotate', "#{service_conf}/systemd/pxp-agent.logrotate")
    when 'sysv'
      if platform.is_deb?
        pkg.install_file('ext/debian/pxp-agent.init', "#{service_conf}/debian/pxp-agent.init")
        pkg.install_file('ext/debian/pxp-agent.default', "#{service_conf}/debian/pxp-agent.default")
      elsif platform.is_sles?
        pkg.install_file('ext/suse/pxp-agent.init', "#{service_conf}/suse/pxp-agent.init")
        pkg.install_file('ext/redhat/pxp-agent.sysconfig', "#{service_conf}/redhat/pxp-agent.sysconfig")
      elsif platform.is_rpm?
        pkg.install_file('ext/redhat/pxp-agent.init', "#{service_conf}/redhat/pxp-agent.init")
        pkg.install_file('ext/redhat/pxp-agent.sysconfig', "#{service_conf}/redhat/pxp-agent.sysconfig")
      end
      pkg.install_file('ext/pxp-agent.logrotate', "#{service_conf}/pxp-agent.logrotate")
    when 'launchd'
      pkg.install_file('ext/osx/pxp-agent.plist', "#{service_conf}/osx/pxp-agent.plist")
      pkg.install_file('ext/osx/pxp-agent.newsyslog.conf', "#{service_conf}/osx/pxp-agent.newsyslog.conf")
    when 'smf'
      pkg.install_file('ext/solaris/smf/pxp-agent.xml', "#{service_conf}/solaris/smf/pxp-agent.xml")
    when /windows|aix/
      # nothing to do
    else
      raise "need to know where to put #{pkg.get_name} service files"
    end
  end
end
