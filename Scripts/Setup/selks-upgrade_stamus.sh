#!/bin/bash

# Copyright(C) 2017, Stamus Networks
# All rights reserved
# Part of Debian SELKS scripts
# Written by Peter Manev <pmanev@stamus-networks.com>
#
# Please run on Debian
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

/bin/systemctl stop kibana

apt-get update && apt-get dist-upgrade

chown -R kibana /usr/share/kibana/optimize/

/bin/systemctl restart elasticsearch
/bin/systemctl restart kibana
/usr/bin/supervisorctl restart scirius 
