#!/bin/bash

# Obligatorios
NODE_HOSTNAME=$1
NODE_IP=$2
MAC=$3

# Variables locales no forman parte de debian installer preseed
BOOT_FILE=pxelinux.0
NET_IFNAMES=net.ifnames=0
NETBOOT_IFACE=eth0
NETBOOT_SERVER=172.17.253.251
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
        APPEND initrd=/debian-installer/amd64/initrd.gz preseed/$interactive preseed/early_command=\"cat /proc/cmdline\" preseed/late_command=\"in-target /usr/bin/busybox tftp $NETBOOT_SERVER -g -r /post.cfg/$NODE_HOSTNAME ; in-target /bin/bash /$NODE_HOSTNAME ; rm /target/$NODE_HOSTNAME\"  netcfg/$link_wait_timeout netcfg/$choose_interface netcfg/$get_ipaddress netcfg/$get_hostname netcfg/$get_netmask netcfg/$get_gateway netcfg/$get_nameservers preseed/$url keyboard-configuration/$xkb_keymap debian-installer/$locale  netcfg/confirm_static=true netcfg/disable_autoconfig=true auto-install/enable=true debconf/priority=critical mirror/$codename pkgsel/$upgrade $BOOT_DEBUG $DEBIAN_FRONTEND --- $NETBOOT_CONSOLE $NET_IFNAMES  " > $NETBOOT_ROOT/nodes.cfg/$NODE_HOSTNAME

echo "serial 1 115200 0
include /nodes.cfg/$NODE_HOSTNAME" > $NETBOOT_ROOT/pxelinux.cfg/$NODE_HOSTNAME

ln -sfv $NETBOOT_ROOT/pxelinux.cfg/$NODE_HOSTNAME  $NETBOOT_ROOT/pxelinux.cfg/01-$(echo $MAC | tr ":" "-")
ln -sfv $NETBOOT_ROOT/pxelinux.cfg/$NODE_HOSTNAME  $NETBOOT_ROOT/pxelinux.cfg/$( printf "%02X" $(echo $NODE_IP | tr "." " " ) )
test ! -e $NETBOOT_ROOT/preseed.cfg/$NODE_HOSTNAME && ln -svf $NETBOOT_ROOT/preseed.cfg/default.preseed $NETBOOT_ROOT/preseed.cfg/$NODE_HOSTNAME
test ! -e $NETBOOT_ROOT/post.cfg/$NODE_HOSTNAME && ln -svf $NETBOOT_ROOT/post.cfg/default.post $NETBOOT_ROOT/post.cfg/$NODE_HOSTNAME
}

_gen-SCRIPT(){

test ! -e $NETBOOT_ROOT/nodes.cfg/localboot && echo "default localboot
label localboot
        LOCALBOOT 0
" > $NETBOOT_ROOT/nodes.cfg/localboot

echo "#!/bin/bash
METHOD=\$1
MAC=\$2
IP=\$3
NODE=\$4

test x\$METHOD == xadd  && echo \"serial 1 115200 0
include /nodes.cfg/localboot
\" >  $NETBOOT_ROOT/pxelinux.cfg/\$NODE 

exit 0

" > $NETBOOT_ROOT/nodes.cfg/boot.node 
chmod +x $NETBOOT_ROOT/nodes.cfg/boot.node

}

_gen-DHCP(){

echo "leasefile-ro 
no-hosts 
log-queries 
no-daemon 
no-resolv 
no-poll
port=0 
log-dhcp 
enable-tftp 
tftp-unique-root 
dhcp-boot=$BOOT_FILE 
dhcp-leasefile=/dev/null 
interface=$NETBOOT_IFACE 
dhcp-range=$NETBOOT_BROADCAST,static 
tftp-root=$NETBOOT_ROOT
dhcp-script=$NETBOOT_ROOT/nodes.cfg/boot.node
dhcp-option=option:router,$NETBOOT_GATEWAY 
dhcp-option=option:dns-server,$NETBOOT_DNS 
" > $NETBOOT_ROOT/dnsmasq.cfg/global.conf 

echo "#!/bin/bash 
sudo pkill dnsmasq
sudo dnsmasq --conf-dir=$NETBOOT_ROOT/dnsmasq.cfg 
" > $NETBOOT_ROOT/run-DNSMASQ.sh 

echo "dhcp-host=$MAC,$NODE_HOSTNAME,$NODE_IP,1h" >  $NETBOOT_ROOT/dnsmasq.cfg/$NODE_HOSTNAME

echo "
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Ejecutar: 

bash ./run-DNSMASQ.sh 

y encender nodo en arranque PXE para comenzar instalación 

NETBOOT_SERVER=$NETBOOT_SERVER
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

}


_setup-netboot(){
local NETBOOT="https://deb.debian.org/debian/dists/bullseye/main/installer-amd64/current/images/netboot/gtk/netboot.tar.gz"
test -e $BOOT_FILE && return

echo "Descargando $NETBOOT .." 
curl -s -L $NETBOOT | tar xzvf -
}

test ! -e $BOOT_FILE && echo "falta archivo $BOOT_FILE " && _setup-netboot
test ! -d pxelinux.cfg && echo "falta directorio pxelinux.cfg" && _setup-netboot
test ! -d  $NETBOOT_ROOT/nodes.cfg && mkdir -v $NETBOOT_ROOT/nodes.cfg
test ! -d  $NETBOOT_ROOT/post.cfg && mkdir -v $NETBOOT_ROOT/post.cfg
test ! -d  $NETBOOT_ROOT/preseed.cfg && mkdir -v $NETBOOT_ROOT/preseed.cfg 
test ! -d $NETBOOT_ROOT/dnsmasq.cfg && mkdir -v $NETBOOT_ROOT/dnsmasq.cfg
cp -v  default.preseed $NETBOOT_ROOT/preseed.cfg  
cp -v  default.post $NETBOOT_ROOT/post.cfg  
test -z $1  && echo "Faltan datos del servidor a instalar.  
Uso:
bash setup-DHCP-TFTP.sh node1 172.17.2.1 3c:ec:ef:18:d6:aa " && exit


_gen-PXE 
_gen-SCRIPT
_gen-DHCP


