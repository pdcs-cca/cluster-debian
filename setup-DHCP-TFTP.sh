#!/bin/bash

# Obligatorios
NODE_HOSTNAME=$1
NODE_IP=$2
MAC=$3

# Variables locales no forman parte de debian installer preseed
BOOT_FILE=pxelinux.0
NET_IFNAMES=net.ifnames=0
NETBOOT_IFACE=eth0
NETBOOT_SERVER=172.17.253.253
NETBOOT_BROADCAST=172.17.0.0
NETBOOT_NETMASK=255.255.0.0
NETBOOT_GATEWAY=$NETBOOT_SERVER
NETBOOT_DNS=8.8.8.8
NETBOOT_ROOT=$PWD
NETBOOT_CONSOLE="console=tty0 console=ttyS1,115200n8"

#NETBOOT_LOCAL="/netboot"
#NETBOOT_REMOTE=$NETBOOT_ROOT 
#NETBOOT_LOCAL=$NETBOOT_LOCAL 
#MASTER_IP=$NETBOOT_SERVER 


_gen-PXE(){
#https://www.debian.org/releases/stable/amd64/ch05s03.en.html
link_wait_timeout=link_wait_timeout=15                          
choose_interface=choose_interface=eth0                          
get_ipaddress=get_ipaddress=$NODE_IP      
get_hostname=get_hostname=$NODE_HOSTNAME                        
get_netmask=get_netmask=$NETBOOT_NETMASK                            
get_gateway=get_gateway=$NETBOOT_SERVER
url=url=tftp://$NETBOOT_SERVER/preseed.cfg/$NODE_HOSTNAME        
get_nameservers=get_nameservers=$NETBOOT_DNS
xkb_keymap=xkb-keymap=us                                        
locale=locale=en_US 
codename=codename=bullseye
upgrade=upgrade=full-upgrade #none, safe-upgrade, full-upgrade
interactive=interactive=false #true, false
DEBIAN_FRONTEND=DEBIAN_FRONTEND=newt # noninteractive, text, newt, gtk  
BOOT_DEBUG=BOOT_DEBUG=2 #0, 1, 2, 3 


echo "default install
label install
        KERNEL /debian-installer/amd64/linux
        APPEND initrd=/debian-installer/amd64/initrd.gz preseed/$interactive preseed/early_command=\"cat /proc/cmdline\" preseed/late_command=\"in-target /usr/bin/busybox tftp $NETBOOT_SERVER -g -r /netboot.post ; in-target /bin/bash /netboot.post ; rm /target/netboot.post\"  netcfg/$link_wait_timeout netcfg/$choose_interface netcfg/$get_ipaddress netcfg/$get_hostname netcfg/$get_netmask netcfg/$get_gateway netcfg/$get_nameservers preseed/$url keyboard-configuration/$xkb_keymap debian-installer/$locale  netcfg/confirm_static=true netcfg/disable_autoconfig=true auto-install/enable=true debconf/priority=critical mirror/$codename pkgsel/$upgrade $BOOT_DEBUG $DEBIAN_FRONTEND --- $NETBOOT_CONSOLE $NET_IFNAMES  " > $NETBOOT_ROOT/nodes.cfg/$NODE_HOSTNAME

echo "serial 1 115200 0
include /nodes.cfg/$NODE_HOSTNAME" > $NETBOOT_ROOT/pxelinux.cfg/$NODE_HOSTNAME

ln -sfv $NETBOOT_ROOT/pxelinux.cfg/$NODE_HOSTNAME  $NETBOOT_ROOT/pxelinux.cfg/$(echo $MAC | tr ":" "-")
ln -sfv $NETBOOT_ROOT/pxelinux.cfg/$NODE_HOSTNAME  $NETBOOT_ROOT/pxelinux.cfg/$( printf "%02X" $(echo $NODE_IP | tr "." " " ) )

ln -svf $NETBOOT_ROOT/preseed.cfg/default.preseed $NETBOOT_ROOT/preseed.cfg/$NODE_HOSTNAME
}

_run-dnsmasq(){

grep -q $MAC $PWD/hosts.dnsmasq || echo "$MAC,$NODE_HOSTNAME,$NODE_IP,1h" >>  $PWD/hosts.dnsmasq

cat<<EOF-> $PWD/run-DNSMASQ.sh 
#!/bin/bash 

sudo pkill dnsmasq
sudo dnsmasq --leasefile-ro --no-hosts --log-queries --no-daemon --no-resolv --no-poll \
--port=0 --log-dhcp --enable-tftp --tftp-unique-root --dhcp-boot=$BOOT_FILE \
--dhcp-leasefile=/dev/null \
--interface=$NETBOOT_IFACE \
--dhcp-range=$NETBOOT_BROADCAST,static \
--tftp-root=$NETBOOT_ROOT \
--dhcp-option=option:router,$NETBOOT_GATEWAY \
--dhcp-option=option:dns-server,$NETBOOT_DNS \
--dhcp-host=$MAC,$NODE_HOSTNAME,$NODE_IP,1h 
EOF-

echo "
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Ejecutar: 

bash ./run-DNSMASQ.sh 

y encender nodo en arranque PXE para comenzar instalación 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

test ! -e netboot.post && echo "!!!!!!!!! Falta archivo netboot.post !!!!!!!!" 

}

_setup-netboot(){
local NETBOOT="https://deb.debian.org/debian/dists/bullseye/main/installer-amd64/current/images/netboot/gtk/netboot.tar.gz"
test -e $BOOT_FILE && return

echo "Descargando $NETBOOT .." 
curl -s -L $NETBOOT | tar xzvf -
}

test -z $1  && echo "falta datos del servidor:  node1 172.17.2.1 3c:ec:ef:18:d6:aa " && exit
test ! -e $BOOT_FILE && echo "falta archivo $BOOT_FILE " && _setup-netboot
test ! -d pxelinux.cfg && echo "falta directorio pxelinux.cfg" && _setup-netboot
test ! -d  $PWD/nodes.cfg && mkdir -v $PWD/nodes.cfg
test ! -d  $PWD/preseed.cfg && mkdir -v $PWD/preseed.cfg 
cp -v  default.preseed $PWD/preseed.cfg  
test ! -e $PWD/hosts.dnsmasq && echo "#$(date)" > $PWD/hosts.dnsmasq

_gen-PXE 
_run-dnsmasq


