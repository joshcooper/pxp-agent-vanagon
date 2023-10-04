component 'runtime' do |pkg, _settings, platform|
  if platform.is_cross_compiled_linux? || platform.name =~ /solaris-11/
    if platform.is_solaris? && !platform.is_cross_compiled? && platform.architecture == 'sparc'
      pkg.build_requires 'pl-gcc10'
      # using binutils in /usr/ccs/bin
    else
      pkg.build_requires "pl-gcc-#{platform.architecture}"
      pkg.build_requires "pl-binutils-#{platform.architecture}"
    end
  elsif platform.is_windows?
    pkg.build_requires "pl-gdbm-#{platform.architecture}"
    pkg.build_requires "pl-iconv-#{platform.architecture}"
    pkg.build_requires "pl-libffi-#{platform.architecture}"
    pkg.build_requires "pl-pdcurses-#{platform.architecture}"
  elsif platform.name =~ /el-[67]|redhatfips-7|sles-1[12]|ubuntu-18.04-amd64/
    pkg.build_requires 'pl-gcc'
  end
end
