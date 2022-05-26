# cluster-debian

* Preparar neetboot y archivo preseed
* Instalar nodo maestro
* Instalar SLURM en nodo maestro 
* Compilar Lustre en nodo maestro


El archivo [setup-DHCP-TFTP.sh](setup-DHCP-TFTP.sh) contiene las opciones para que dnsmasq atienda la solicitud dhcp y sirva como tftp para la entrega de los archivos necesarios para el arranque del nodo.

Uso 
~~~bash
git clone https://github.com/pdcs-cca/cluster-debian.git  
cd debian-cluster
bash setup-DHCP-TFTP.sh  nodo IP MAC
bash run-DNSMASQ.sh
~~~

Uso de dnsmasq versión 2.86 
https://thekelleys.org.uk/dnsmasq/dnsmasq-2.86.tar.gz


### Referencias
https://www.debian.org/releases/stable/amd64/apb.es.html
https://www.debian.org/releases/stable/amd64/ch05s03.en.html
https://preseed.debian.net/debian-preseed/bullseye/amd64-main-full.txt

man  dnsmasq

