#!/usr/bin/env bash
# Revert from hybrid Stretch/Jessie Volumio images back to pristine Jessie.
# Use at your own risk ;-)
set -eo pipefail


source /etc/os-release
echo -e "Fixing Jessie/Stretch hybrid Volumio images:\nv${VOLUMIO_VERSION} - ${VOLUMIO_HARDWARE}"
if [[ -f /usr/bin/vtcs ]] && [[ ${VERSION_ID} == 8 ]]; then
  echo "Tidal Connect found, removing Stretch libs"
  apt-cache policy libc6
elif [[ ${VERSION_ID} -ge 8 ]]; then
  echo "Probably nothing to do here?"
  exit 1
fi

echo "Fixing apt repository"
cat <<-EOF > /etc/apt/sources.list
deb http://archive.volumio.org/raspbian/ jessie main contrib non-free rpi
#deb-src http://archive.volumio.org/raspbian/ jessie main contrib non-free rpi

# This is required to convince APT that there were stretch libs installed at some point
# Don't worry, we won't use it after fixing things..
deb http://raspbian.raspberrypi.org/raspbian/ stretch main contrib non-free rpi
EOF

echo "Fixing releases"
cat <<-EOF >/etc/apt/preferences
Package: raspberrypi-bootloader
Pin: release *
Pin-Priority: -1

Package: raspberrypi-kernel
Pin: release *
Pin-Priority: -1

# Fix broken Jessie/Stretch hybrid images
Package: *
Pin: release n=jessie
Pin-Priority: 1001

Package: *
Pin: release n=stretch
Pin-Priority: -1
EOF

apt-get update
echo "Confirming we have Stretch shenanigans"
apt-cache policy libc6

echo "Reverting back to pristine Jessie"
apt-get -y --force-yes install libc6
apt-get -y --force-yes autoremove 


