#!/usr/bin/env bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# post-installation script for Proxmox
#
# License: BSD (Berkeley Software Distribution)
#
################################################################################
#
# Assumptions: proxmox installed
#
# Notes:
# to disable the MOTD banner, set the env NO_MOTD_BANNER to true (export NO_MOTD_BANNER=true)
#
################################################################################
#
#    THERE ARE NO USER CONFIGURABLE OPTIONS IN THIS SCRIPT
#
################################################################################


# Set the local
export LANG="en_US.UTF-8"
export LC_ALL="C"



## Force APT to use IPv4
echo -e "Acquire::ForceIPv4 \"true\";\\n" > /etc/apt/apt.conf.d/99force-ipv4

## disable enterprise proxmox repo
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
  echo -e "#deb https://enterprise.proxmox.com/debian buster pve-enterprise\\n" > /etc/apt/sources.list.d/pve-enterprise.list
fi
## enable public proxmox repo
if [ ! -f /etc/apt/sources.list.d/proxmox.list ] && [ ! -f /etc/apt/sources.list.d/pve-public-repo.list ] && [ ! -f /etc/apt/sources.list.d/pve-install-repo.list ] ; then
  echo -e "deb http://download.proxmox.com/debian buster pve-no-subscription\\n" > /etc/apt/sources.list.d/pve-public-repo.list
  
fi

## enable pvetest proxmox repo
if [ ! -f /etc/apt/sources.list.d/pvetest.list ] ; then
  echo -e "deb http://download.proxmox.com/debian buster pvetest\\n" > /etc/apt/sources.list.d/pvetest.list
fi

## Add non-free to sources
sed -i "s/main contrib/main non-free contrib/g" /etc/apt/sources.list

## Add the latest ceph provided by proxmox
# echo "deb http://download.proxmox.com/debian/ceph-luminous buster main" > /etc/apt/sources.list.d/ceph.list

## Refresh the package lists
apt update > /dev/null


## Install common system utilities
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install tuned apt-transport-https ca-certificates curl gnupg2 software-properties-common vim git nfs-kernel-server vim git tmux

## Remove conflicting utilities
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' purge ntp openntpd chrony ksm-control-daemon

## Fix no public key error for debian repo
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install debian-archive-keyring

## Update proxmox and install various system utils
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' dist-upgrade
pveam update

## Fix no public key error for debian repo
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install debian-archive-keyring

## Install openvswitch for a virtual internal network
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install openvswitch-switch

## Install zfs support, appears to be missing on some Proxmox installs.
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install zfsutils

## Install zfs-auto-snapshot
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install zfs-auto-snapshot
# make 5min snapshots , keep 12 5min snapshots
if [ -f "/etc/cron.d/zfs-auto-snapshot" ] ; then
  sed -i 's|--keep=[0-9]*|--keep=12|g' /etc/cron.d/zfs-auto-snapshot
  sed -i 's|*/[0-9]*|*/5|g' /etc/cron.d/zfs-auto-snapshot
fi
# keep 24 hourly snapshots
if [ -f "/etc/cron.hourly/zfs-auto-snapshot" ] ; then
  sed -i 's|--keep=[0-9]*|--keep=24|g' /etc/cron.hourly/zfs-auto-snapshot
fi
# keep 7 daily snapshots
if [ -f "/etc/cron.daily/zfs-auto-snapshot" ] ; then
  sed -i 's|--keep=[0-9]*|--keep=7|g' /etc/cron.daily/zfs-auto-snapshot
fi
# keep 4 weekly snapshots
if [ -f "/etc/cron.weekly/zfs-auto-snapshot" ] ; then
  sed -i 's|--keep=[0-9]*|--keep=4|g' /etc/cron.weekly/zfs-auto-snapshot
fi
# keep 3 monthly snapshots
if [ -f "/etc/cron.monthly/zfs-auto-snapshot" ] ; then
  sed -i 's|--keep=[0-9]*|--keep=3|g' /etc/cron.monthly/zfs-auto-snapshot
fi


## Install missing ksmtuned
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install ksmtuned
systemctl enable ksmtuned
systemctl enable ksm

echo 1 >/sys/kernel/mm/ksm/run
echo 1000 >/sys/kernel/mm/ksm/sleep_millisecs

## Refresh the package lists
apt update > /dev/null
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install apt-transport-https ca-certificates curl gnupg2 software-properties-common

# add docker key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

/usr/bin/env DEBIAN_FRONTEND=noninteractive add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
   $(lsb_release -cs) \
   stable"
   
apt update > /dev/null

## Install common system utilities
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install -y whois omping tmux zsh sshpass wget axel nano pigz net-tools htop iptraf iotop iftop iperf vim vim-nox unzip zip curl dos2unix dialog mlocate build-essential git ipset docker-ce samba



#snmpd snmp-mibs-downloader


echo "Installing kernel pve-kernel-5.0.21-1-pve"
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install pve-kernel-5.0.21-1-pve

## Detect AMD EPYC CPU and install kernel 5.0
if [ "$(grep -i -m 1 "model name" /proc/cpuinfo | grep -i "EPYC")" != "" ]; then
  echo "AMD EPYC detected"
  #Apply EPYC fix to kernel : Fixes random crashing and instability
  if ! grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub | grep -q "idle=nomwait" ; then
    echo "Setting kernel idle=nomwait"
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="idle=nomwait /g' /etc/default/grub
    update-grub
  fi
fi

if [ "$(grep -i -m 1 "model name" /proc/cpuinfo | grep -i "EPYC")" != "" ] || [ "$(grep -i -m 1 "model name" /proc/cpuinfo | grep -i "Ryzen")" != "" ]; then
  ## Add msrs ignore to fix Windows guest on EPIC/Ryzen host
  echo "options kvm ignore_msrs=Y" >> /etc/modprobe.d/kvm.conf
  echo "options kvm report_ignored_msrs=N" >> /etc/modprobe.d/kvm.conf
fi

## Install kexec, allows for quick reboots into the latest updated kernel set as primary in the boot-loader.
# use command 'reboot-quick'
echo "kexec-tools kexec-tools/load_kexec boolean false" | debconf-set-selections
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install kexec-tools

if [ -f "/etc/systemd/system/kexec-pve.service" ]; then
cat <<'EOF' > /etc/systemd/system/kexec-pve.service
[Unit]
Description=boot into into the latest pve kernel set as primary in the boot-loader
Documentation=man:kexec(8)
DefaultDependencies=no
Before=shutdown.target umount.target final.target

[Service]
Type=oneshot
ExecStart=/sbin/kexec -l /boot/pve/vmlinuz --initrd=/boot/pve/initrd.img --reuse-cmdline

[Install]
WantedBy=kexec.target
EOF
systemctl enable kexec-pve.service
echo "alias reboot-quick='systemctl kexec'" >> /root/.bash_profile
fi 

if [ ! -f "/usr/sbin/reboot-full" ]; 
then
  mv /usr/sbin/reboot{,-full}
  cat <<'EOF' > /usr/sbin/reboot
  #!/usr/bin/sh
  /sbin/kexec -l /boot/pve/vmlinuz --initrd=/boot/pve/initrd.img --reuse-cmdline && /sbin/kexec -e
EOF
chmod +x /usr/sbin/reboot
fi

## Disable portmapper / rpcbind (security)
#systemctl disable rpcbind
#systemctl stop rpcbind

## Set Timezone to UTC and enable NTP
timedatectl set-timezone America/Chicago
cat <<EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=time.cloudflare.com
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF
service systemd-timesyncd start
timedatectl set-ntp true

## Set pigz to replace gzip, 2x faster gzip compression
cat  <<EOF > /bin/pigzwrapper
#!/bin/sh
PATH=/bin:\$PATH
GZIP="-1"
exec /usr/bin/pigz "\$@"
EOF
mv -f /bin/gzip /bin/gzip.original
cp -f /bin/pigzwrapper /bin/gzip
chmod +x /bin/pigzwrapper
chmod +x /bin/gzip

# ## Protect the web interface with fail2ban
# /usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install fail2ban
# # shellcheck disable=1117
# cat <<EOF > /etc/fail2ban/filter.d/proxmox.conf
# [Definition]
# failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
# ignoreregex =
# EOF
# cat <<EOF > /etc/fail2ban/jail.d/proxmox.conf
# [proxmox]
# enabled = true
# port = https,http,8006
# filter = proxmox
# logpath = /var/log/daemon.log
# maxretry = 3
# # 1 hour
# bantime = 3600
# EOF
# cat <<EOF > /etc/fail2ban/jail.local
# [DEFAULT]
# banaction = iptables-ipset-proto4
# EOF
# systemctl enable fail2ban
##testing
#fail2ban-regex /var/log/daemon.log /etc/fail2ban/filter.d/proxmox.conf

## Increase vzdump backup speed, enable pigz and fix ionice
sed -i "s/#bwlimit:.*/bwlimit: 0/" /etc/vzdump.conf
sed -i "s/#pigz:.*/pigz: 1/" /etc/vzdump.conf
sed -i "s/#ionice:.*/ionice: 5/" /etc/vzdump.conf


## Remove subscription banner
if [ -f "/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js" ] ; then
  sed -i "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
  # create a daily cron to make sure the banner does not re-appear
  cat <<'EOF' > /etc/cron.daily/proxmox-nosub
#!/bin/sh
# eXtremeSHOK.com Remove subscription banner
sed -i "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
EOF
  chmod 755 /etc/cron.daily/proxmox-nosub
fi

HOSTNAME=$(cat /etc/hostname)

## Pretty MOTD BANNER
if [ -z "${NO_MOTD_BANNER}" ] ; then
  if ! grep -q "4act.com" "/etc/motd" ; then
  
    HOSTNAME=$(cat /etc/hostname)
    cat << 'EOF' > /etc/motd
 
 
This system ($HOSTNAME.hartlee.lan) is optimised and managed by:

 ______    __                  ____                          ___       ____                                         ___
/\__  _\  /\ \                /\  _`\                       /\_ \     /\  _`\                        __            /\_ \
\/_/\ \/  \ \ \___       __   \ \ \L\ \      __      __     \//\ \    \ \ \/\ \     __       ___    /\_\      __   \//\ \
   \ \ \   \ \  _ `\   /'__`\  \ \ ,  /    /'__`\  /'__`\     \ \ \    \ \ \ \ \  /'__`\   /' _ `\  \/\ \   /'__`\   \ \ \
    \ \ \   \ \ \ \ \ /\  __/   \ \ \\ \  /\  __/ /\ \L\.\_    \_\ \_   \ \ \_\ \/\ \L\.\_ /\ \/\ \  \ \ \ /\  __/    \_\ \_
     \ \_\   \ \_\ \_\\ \____\   \ \_\ \_\\ \____\\ \__/.\_\   /\____\   \ \____/\ \__/.\_\\ \_\ \_\  \ \_\\ \____\   /\____\
      \/_/    \/_/\/_/ \/____/    \/_/\/ / \/____/ \/__/\/_/   \/____/    \/___/  \/__/\/_/ \/_/\/_/   \/_/ \/____/   \/____/

                                                                                                            sysadmin@4act.com


+---------------------------------------------------------------------------------------------------------------------------+

 :'####::::'##::::'##::'######::'########:::::::'###::::'########:::'######::'##::::'##::::'########::'########:'##:::::'##:
 :. ##::::: ##:::: ##:'##... ##: ##.....:::::::'## ##::: ##.... ##:'##... ##: ##:::: ##:::: ##.... ##:... ##..:: ##:'##: ##:
 :: ##::::: ##:::: ##: ##:::..:: ##:::::::::::'##:. ##:: ##:::: ##: ##:::..:: ##:::: ##:::: ##:::: ##:::: ##:::: ##: ##: ##:
 :: ##::::: ##:::: ##:. ######:: ######::::::'##:::. ##: ########:: ##::::::: #########:::: ########::::: ##:::: ##: ##: ##:
 :: ##::::: ##:::: ##::..... ##: ##...::::::: #########: ##.. ##::: ##::::::: ##.... ##:::: ##.... ##:::: ##:::: ##: ##: ##:
 :: ##::::: ##:::: ##:'##::: ##: ##:::::::::: ##.... ##: ##::. ##:: ##::: ##: ##:::: ##:::: ##:::: ##:::: ##:::: ##: ##: ##:
 :'####::::. #######::. ######:: ########:::: ##:::: ##: ##:::. ##:. ######:: ##:::: ##:::: ########::::: ##::::. ###. ###::
 :....::::::.......::::......:::........:::::..:::::..::..:::::..:::......:::..:::::..:::::........::::::..::::::...::...:::


+---------------------------------------------------------------------------------------------------------------------------+
|------------------| do yo thing below (provided you agree with the authorized use policy and usual legal stuff) |----------|
+---------------------------------------------------------------------------------------------------------------------------+


EOF
    sed -i "s/\$HOSTNAME/$HOSTNAME/" /etc/motd
    cat /etc/motd
  fi
fi


## Increase max user watches
# BUG FIX : No space left on device

! grep -q "net.core.netdev_budget" /etc/sysctl.conf && echo "net.core.netdev_budget=600" >> /etc/sysctl.conf && sysctl -p;
! grep -q "net.core.netdev_max_backlog" /etc/sysctl.conf && echo "net.core.netdev_max_backlog=5000" >> /etc/sysctl.conf && sysctl -p;
! grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf && echo "fs.inotify.max_user_watches=1048576" >> /etc/sysctl.conf && sysctl -p;
! grep -q "vm.min_free_kbytes" /etc/sysctl.conf && echo "vm.min_free_kbytes=524288" >> /etc/sysctl.conf && sysctl -p;
! grep -q "vm.swappiness" /etc/sysctl.conf && echo "vm.swappiness=5" >> /etc/sysctl.conf >> /etc/sysctl.conf && sysctl -p;




## Increase max FD limit / ulimit
cat <<EOF >> /etc/security/limits.conf
# eXtremeSHOK.com Increase max FD limit / ulimit
* soft     nproc          500000
* hard     nproc          500000
* soft     nofile         500000
* hard     nofile         500000
root soft     nproc          500000
root hard     nproc          500000
root soft     nofile         500000
root hard     nofile         500000
EOF

## Enable TCP BBR congestion control
cat <<EOF > /etc/sysctl.d/10-kernel-bbr.conf
# eXtremeSHOK.com
# TCP BBR congestion control
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

## Increase kernel max Key limit
cat <<EOF > /etc/sysctl.d/60-maxkeys.conf
# eXtremeSHOK.com
# Increase kernel max Key limit
kernel.keys.root_maxkeys=1000000
kernel.keys.maxkeys=1000000
EOF

## Set systemd ulimits
echo "DefaultLimitNOFILE=256000" >> /etc/systemd/system.conf
echo "DefaultLimitNOFILE=256000" >> /etc/systemd/user.conf
echo 'session required pam_limits.so' | tee -a /etc/pam.d/common-session-noninteractive
echo 'session required pam_limits.so' | tee -a /etc/pam.d/common-session
echo 'session required pam_limits.so' | tee -a /etc/pam.d/runuser-l

## Set ulimit for the shell user
cd ~ && echo "ulimit -n 500000" >> .bashrc ; echo "ulimit -n 500000" >> .profile

## Optimise ZFS arc size
if [ "$(command -v zfs)" != "" ] ; then
  RAM_SIZE_GB=$(( $(vmstat -s | grep -i "total memory" | xargs | cut -d" " -f 1) / 1024 / 1000))
  if [[ RAM_SIZE_GB -lt 16 ]] ; then
    # 1GB/1GB
    MY_ZFS_ARC_MIN=1073741824
    MY_ZFS_ARC_MAX=1073741824
  else
    MY_ZFS_ARC_MIN=$((RAM_SIZE_GB * 1073741824 / 5))
    MY_ZFS_ARC_MAX=$((RAM_SIZE_GB * 1073741824 / 2))
  fi
  # Enforce the minimum, incase of a faulty vmstat
  if [[ MY_ZFS_ARC_MIN -lt 1073741824 ]] ; then
    MY_ZFS_ARC_MIN=1073741824
  fi
  if [[ MY_ZFS_ARC_MAX -lt 1073741824 ]] ; then
    MY_ZFS_ARC_MAX=1073741824
  fi
  cat <<EOF > /etc/modprobe.d/zfs.conf
# eXtremeSHOK.com ZFS tuning

# Use 1/16 RAM for MAX cache, 1/8 RAM for MIN cache, or 1GB
options zfs zfs_arc_min=$MY_ZFS_ARC_MIN
options zfs zfs_arc_max=$MY_ZFS_ARC_MAX

# use the prefetch method
options zfs l2arc_noprefetch=0

# max write speed to l2arc
# tradeoff between write/read and durability of ssd (?)
# default : 8 * 1024 * 1024
# setting here : 500 * 1024 * 1024
options zfs l2arc_write_max=524288000
EOF
fi

# propagate the setting into the kernel
update-initramfs -u -k all
update-grub

mv ~/.oh-my-zsh{,.bak}
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

#bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait

#systemctl enable --now netdata

## Remove no longer required packages and purge old cached updates
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' autoremove
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' autoclean

# Install Veeam Linux Agent
# wget https://download2.veeam.com/veeam-release-deb_1.0.7_amd64.deb && dpkg -i ./veeam-release* && apt-get update && apt-get install veeam -y

# Install wireguard
echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 648ACFD622F3D138 04EE7237B7D453EC
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' update
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::='--force-confdef' install wireguard

curl -L https://github.com/docker/machine/releases/latest/download/docker-machine-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-machine && chmod +x /usr/local/bin/docker-machine
sudo curl -L https://github.com/janeczku/docker-machine-vultr/releases/latest/download/docker-machine-driver-vultr-Linux-x86_64 -o /usr/local/bin/docker-machine-driver-vultr && sudo chmod +x /usr/local/bin/docker-machine-driver-vultr
sudo curl -L https://github.com/kubernetes/minikube/releases/latest/download/docker-machine-driver-kvm2 -o /usr/local/bin/docker-machine-driver-kvm2 && sudo chmod +x /usr/local/bin/docker-machine-driver-*



## Script Finish
echo -e '\033[1;33m Finished....please restart the system \033[0m'
