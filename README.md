# cluster-debian

* Preparar neetboot y archivo preseed
* Instalar nodo maestro
* Instalar SLURM en nodo maestro 
* Compilar Lustre en nodo maestro


El archivo [run-DHCP-TFTP.sh](run-DHCP-TFTP.sh) contiene las opciones para que dnsmasq atienda la solicitud dhcp y sirva como tftp para la entrega de los archivos necesarios para el arranque del nodo.

Uso 
~~~bash
git clone 
cd debian-cluster
bash run-DHCP-TFTP.sh  nodo IP MAC
~~~


### Referencias
https://www.debian.org/releases/stable/amd64/apb.es.html
https://www.debian.org/releases/stable/amd64/ch05s03.en.html                                                                                                                 
https://preseed.debian.net/debian-preseed/bullseye/amd64-main-full.txt

