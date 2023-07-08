platform "aix-7.2-ppc" do |plat|
  plat.make "gmake"
  plat.patch "/opt/freeware/bin/patch"
  plat.rpmbuild "/usr/bin/rpm"
  plat.servicetype "aix"
  plat.tar "/opt/freeware/bin/tar"

  plat.provision_with %[
curl -O https://artifactory.delivery.puppetlabs.net/artifactory/generic__buildsources/openssl-1.1.2.2000.tar.Z;
uncompress openssl-1.1.2.2000.tar.Z;
tar xvf openssl-1.1.2.2000.tar;
cd openssl-1.1.2.2000 && /usr/sbin/installp -acgwXY -d $PWD openssl.base;
curl --output yum.sh https://artifactory.delivery.puppetlabs.net/artifactory/generic__buildsources/buildsources/aix-yum.sh && sh yum.sh]

  # After installing yum, but before yum installing packages, point yum to artifactory
  # AIX sed doesn't support in-place replacement, so download GNU sed and use that
  plat.provision_with %[
rpm -Uvh https://artifactory.delivery.puppetlabs.net/artifactory/rpm__remote_aix_linux_toolbox/RPMS/ppc/sed/sed-4.1.1-1.aix5.1.ppc.rpm;
/opt/freeware/bin/sed -i 's|https://anonymous:anonymous@public.dhe.ibm.com/aix/freeSoftware/aixtoolbox/RPMS|https://artifactory.delivery.puppetlabs.net/artifactory/rpm__remote_aix_linux_toolbox/RPMS|' /opt/freeware/etc/yum/yum.conf]

  # yum.sh downloads rpm.rte containing several base packages including curl
  # 7.51. However, that version isn't compatible with cmake. If we update curl
  # specifically, then yum/python/libcurl will be in an inconsistent state. So
  # run `yum update` to update to newer versions while maintaining compatible
  # versions.
  plat.provision_with 'yum update --assumeyes --skip-broken'

  packages = %w(
    cmake
    coreutils
    gcc
    gcc-c++
    gettext
    make
    sed
    tar
  )
  plat.provision_with "yum install --assumeyes #{packages.join(' ')}"

  # No upstream rsync packages
  plat.provision_with "rpm -Uvh --replacepkgs https://artifactory.delivery.puppetlabs.net/artifactory/rpm__remote_aix_linux_toolbox/RPMS/ppc/rsync/rsync-3.0.6-1.aix5.3.ppc.rpm"

  # lots of things expect mktemp to be installed in the usual place, so link it
  plat.provision_with "ln -sf /opt/freeware/bin/mktemp /usr/bin/mktemp"

  plat.install_build_dependencies_with "yum install --assumeyes "
  plat.vmpooler_template "aix-7.2-power"
end
