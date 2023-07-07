component 'leatherman' do |pkg, settings, platform|
  pkg.load_from_json('configs/components/leatherman.json')

  make = platform[:make]

  if platform.is_macos?
    pkg.build_requires 'cmake'
    pkg.build_requires 'gettext'
  elsif platform.is_cross_compiled_linux? || platform.name =~ /solaris-11/
    pkg.build_requires 'pl-cmake'
    pkg.build_requires 'pl-gettext'
  elsif platform.is_windows?
    pkg.build_requires 'cmake'
    pkg.build_requires "pl-gettext-#{platform.architecture}"
  elsif platform.name =~ /el-[67]|redhatfips-7|sles-12|ubuntu-18.04-amd64/
    pkg.build_requires 'pl-cmake'
    pkg.build_requires 'pl-gettext'
    pkg.build_requires 'runtime'
  end

  pkg.build_requires 'puppet-runtime' # Provides curl and ruby

  pkg.build_requires 'runtime' unless platform.is_linux?

  ruby = "#{settings[:host_ruby]} -rrbconfig"

  leatherman_locale_var = ''
  special_flags = ''
  boost_static_flag = ''

  # cmake on OSX is provided by brew
  # a toolchain is not currently required for OSX since we're building with clang.
  if platform.is_macos?
    toolchain = ''
    cmake = '/usr/local/bin/cmake'
    boost_static_flag = '-DBOOST_STATIC=OFF'
    special_flags = "-DCMAKE_CXX_FLAGS='#{settings[:cflags]} -Wno-deprecated-declarations' -DENABLE_CXX_WERROR=OFF -DLEATHERMAN_MOCK_CURL=FALSE"
    if platform.is_cross_compiled?
      pkg.environment 'CXX', 'clang++ -target arm64-apple-macos11' if platform.name =~ /osx-11/
      pkg.environment 'CXX', 'clang++ -target arm64-apple-macos12' if platform.name =~ /osx-12/
    end
  elsif platform.is_cross_compiled_linux?
    ruby = "#{settings[:host_ruby]} -r#{settings[:datadir]}/doc/rbconfig-#{settings[:ruby_version]}-orig.rb"
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/#{settings[:platform_triple]}/pl-build-toolchain.cmake"
    cmake = '/opt/pl-build-tools/bin/cmake'
    special_flags = "-DCMAKE_CXX_FLAGS='-DBOOST_UUID_RANDOM_PROVIDER_FORCE_POSIX -Wno-deprecated-declarations'"
    pkg.environment 'PATH' => "/opt/pl-build-tools/bin:$$PATH:#{settings[:bindir]}"
  elsif platform.is_solaris?
    if platform.architecture == 'sparc'
      ruby = "#{settings[:host_ruby]} -r#{settings[:datadir]}/doc/rbconfig-#{settings[:ruby_version]}-orig.rb"
      special_flags += " -DCMAKE_EXE_LINKER_FLAGS=' /opt/puppetlabs/puppet/lib/libssl.so /opt/puppetlabs/puppet/lib/libcrypto.so /opt/puppetlabs/puppet/lib/libgcc_s.so' " if platform.name =~ /^solaris-10/
      special_flags += " -DCMAKE_EXE_LINKER_FLAGS=' /opt/puppetlabs/puppet/lib/libssl.so /opt/puppetlabs/puppet/lib/libcrypto.so' " if platform.name =~ /^solaris-11/
    end

    toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/#{settings[:platform_triple]}/pl-build-toolchain.cmake"
    cmake = "/opt/pl-build-tools/i386-pc-solaris2.#{platform.os_version}/bin/cmake"

    # FACT-1156: If we build with -O3, solaris segfaults due to something in std::vector
    special_flags += "-DCMAKE_CXX_FLAGS_RELEASE='-O2 -DNDEBUG' -DCMAKE_CXX_FLAGS='-Wno-deprecated-declarations' "
  elsif platform.is_windows?
    make = "#{settings[:gcc_bindir]}/mingw32-make"
    pkg.environment 'PATH', "$(shell cygpath -u #{settings[:libdir]}):$(shell cygpath -u #{settings[:gcc_bindir]}):$(shell cygpath -u #{settings[:bindir]}):/cygdrive/c/Windows/system32:/cygdrive/c/Windows:/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0"
    pkg.environment 'CYGWIN', settings[:cygwin]

    cmake = 'C:/ProgramData/chocolatey/bin/cmake.exe -G "MinGW Makefiles"'
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=#{settings[:tools_root]}/pl-build-toolchain.cmake"
    special_flags += " -DCMAKE_CXX_FLAGS='-Wno-deprecated-declarations' "

    # Use environment variable set in environment.bat to find locale files
    leatherman_locale_var = "-DLEATHERMAN_LOCALE_VAR='PUPPET_DIR' -DLEATHERMAN_LOCALE_INSTALL='share/locale'"
  elsif platform.name =~ /el-[67]|redhatfips-7|sles-12|ubuntu-18.04-amd64/ ||
        platform.is_aix?
    toolchain = '-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/pl-build-toolchain.cmake'
    cmake = '/opt/pl-build-tools/bin/cmake'
    special_flags += " -DCMAKE_CXX_FLAGS='-Wno-deprecated-declarations' "
  else
    # These platforms use the default OS toolchain, rather than pl-build-tools
    pkg.environment 'CPPFLAGS', settings[:cppflags]
    pkg.environment 'LDFLAGS', settings[:ldflags]
    cmake = 'cmake'
    toolchain = ''
    boost_static_flag = ''

    # Workaround for hanging leatherman tests (-fno-strict-overflow)
    special_flags = " -DENABLE_CXX_WERROR=OFF -DCMAKE_CXX_FLAGS='#{settings[:cflags]} -fno-strict-overflow -Wno-deprecated-declarations' "
  end

  if platform.is_linux?
    # Ensure our gettext packages are found before system versions
    pkg.environment 'PATH', '/opt/pl-build-tools/bin:$(PATH)'
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
    ["#{cmake} \
        #{toolchain} \
        -DLEATHERMAN_GETTEXT=ON \
        -DCMAKE_VERBOSE_MAKEFILE=ON \
        -DCMAKE_PREFIX_PATH=#{settings[:prefix]} \
        -DCMAKE_INSTALL_PREFIX=#{settings[:prefix]} \
        -DCMAKE_INSTALL_RPATH=#{settings[:libdir]} \
        #{leatherman_locale_var} \
        -DLEATHERMAN_SHARED=TRUE \
        #{special_flags} \
        #{boost_static_flag} \
        -DBoost_NO_BOOST_CMAKE=ON \
        ."]
  end

  pkg.build do
    ["#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1)"]
  end

  # Make test will explode horribly in a cross-compile situation
  # Tests will be skipped on AIX until they are expected to pass
  if !platform.is_cross_compiled? && !platform.is_aix?
    test_locale = 'LANG=C LC_ALL=C' if platform.is_solaris? && platform.architecture != 'sparc' || platform.name =~ /debian-10/

    pkg.check do
      ["LEATHERMAN_RUBY=#{settings[:libdir]}/$(shell #{ruby} -e 'print RbConfig::CONFIG[\"LIBRUBY_SO\"]') \
       LD_LIBRARY_PATH=#{settings[:libdir]} LIBPATH=#{settings[:libdir]} #{test_locale} #{make} test ARGS=-V"]
    end
  end

  pkg.install do
    ["#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1) install"]
  end
end
