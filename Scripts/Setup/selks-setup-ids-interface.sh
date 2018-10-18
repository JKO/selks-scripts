#!/bin/bash

# Copyright(C) 2018, Stamus Networks
# All rights reserved
# Part of Debian SELKS scripts
# Written by Peter Manev <pmanev@stamus-networks.com>
#
# Please run on Debian
#
# This script comes with ABSOLUTELY NO WARRANTY!
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

if (( $EUID != 0 )); then
     echo -e "Please run this script as root or with \"sudo\".\n"
     exit 1
fi

echo -e "\n### Setting up sniffing interface  ###\n"
echo -e "\nPlease supply a network interface(s) to set up SELKS Suricata IDPS thread detection on"

function getInterfaces {
  intfnum=0
  for interface in $(ls /sys/class/net); do echo "${intfnum}: ${interface}"; ((intfnum++)) ; done
  
  echo -e "Please type in interface or space delimited interfaces below and hit \"Enter\"."
  echo -e "Example: eth1"
  echo -e "OR"
  echo -e "Example: eth1 eth2 eth3"
  echo -e "\nConfigure threat detection for INTERFACE(S): "
  read interfaces
  
  echo -e "\nThe supplied network interface(s):  ${interfaces} \n";
  INTERFACE_EXISTS="YES"
  if [ -z "${interfaces}" ] ; then
    echo -e "\nNo input provided at all."
    echo -e "Exiting with ERROR...."
    INTERFACE_EXISTS="NO"
    exit 1
  fi
  
  for interface in ${interfaces}
  do
    if ! grep --quiet "${interface}" /proc/net/dev ; then
        echo -e "\nUSAGE: `basename $0` -> the script requires at least 1 argument - a network interface!"
        echo -e "#######################################"
        echo -e "Interface: ${interface} is NOT existing."
        echo -e "#######################################"
        echo -e "Please supply a correct/existing network interface or check your spelling.\n"
        INTERFACE_EXISTS="NO"
    fi
    
  done
}

getInterfaces

while [[ ${INTERFACE_EXISTS} != "YES"  ]]; do
  getInterfaces
done

for interface in ${interfaces}
do
  isitup=$(cat /sys/class/net/${interface}/operstate)
  if [[ ${isitup} != "up"  ]]; then
      echo -e "\nThe specified interface - ${interface} - is not up."
      echo -e "Setting it up....\n"
      ip link set "${interface}" up
  fi
  # we make sure we don't interfere with any static or dhcp settings in /etc/network/interfaces
  if ! grep --quiet "${interface}" /etc/network/interfaces ; then
      #Example: /etc/network/interfaces.d/enp0s8 ->
      #auto enp0s8 
      #iface enp0s8 inet manual
      echo "# Stamus Networks SELKS ${interface} interface set up auto generated!" > /etc/network/interfaces.d/"${interface}"
      echo -e "auto ${interface} \n" >> /etc/network/interfaces.d/"${interface}"
      echo -e "iface ${interface} inet manual\n" >> /etc/network/interfaces.d/"${interface}"
      echo -e "    up ip link set dev ${interface} up\n" >> /etc/network/interfaces.d/"${interface}"
      echo -e "    down ip link set dev ${interface} down\n" >> /etc/network/interfaces.d/"${interface}"
  fi

done


# Set up  Suricata yaml configuration for the given interfaces
intfconfig=/etc/suricata/selks5-interfaces-config.yaml

cat <<EOF > ${intfconfig}
%YAML 1.1
---
# AUTOGENERATED by Stamus SELKS set up script
# Linux high speed capture support
af-packet:
  # Put default values here. These will be used for an interface that is not
  # in the list above.
  - interface: default
    #threads: auto
    #use-mmap: no
    #rollover: yes
    #tpacket-v3: yes
EOF

cluster_id=99
for interface in ${interfaces}
do
cat <<EOF >> ${intfconfig}
  - interface: ${interface}
    threads: auto
    cluster-id: ${cluster_id}
    cluster-type: cluster_flow
    defrag: yes
    use-mmap: yes
    #mmap-locked: yes
    tpacket-v3: yes
    ring-size: 2048
    block-size: 32768
    #block-timeout: 10
    #use-emergency-flush: yes
    #checksum-checks: kernel
    #bpf-filter: port 80 or udp
    #copy-mode: ips
    #copy-iface: eth1.
EOF
((cluster_id++))
done


/bin/systemctl stop suricata
rm -rf /var/run/suricata.pid
/bin/systemctl start suricata

echo "DONE!"



