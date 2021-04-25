# Création d'une VM de jeux sous Win10



## Etape 1 : activer l'IOMMU (Input Output Memory Management Unit) pour Intel

En activant cette fonction, une machine virtuelle crée sur notre hyperviseur Proxmox va pouvoir directement accéder à un périphérique PCI de notre hôte (par exemple une carte graphique en PCI Express) 

Il faut activer cette fonction dans le bios de la carte mère de votre hôte Proxmox.

Dans mon cas, une carte mère ASUS, les 2 paramètres à activer sont :

- Activer Intel VT-d (System Agent Configuration > VT-d)
- Activer la virtualisation du processeur (CPU Configuration > Intel Virtualisation Technology)



## Etape 2 : activer l'IOMMU dans Proxmox (processeur Intel)

Une fois connectée en SSH (root) sur votre hôte (ou via le menu Shell du GUI Proxmox)

```bash
# Editer le grub
nano /etc/default/grub

# Commenter la ligne suivante
GRUB_CMDLINE_LINUX_DEFAULT="quiet"

# Ajouter la ligne suivante
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt kvm.ignore_msrs=1 video=vesafb:off video=efifb:off intremap=no_x2apic_optout"

# Sauvergarder, fermer le fichier et MAJ Grub
update-grub

# Redemarrer Proxmox
reboot

# Verifier que la commande suivante ramène des infos
dmesg | grep -e DMAR -e IOMMU

# Listes les devices PCI
lspci -nn

# Résultats pour ma GTX 1650
# 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU107 [10de:1f82] (rev a1)
# 01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:10fa] (rev a1)

# Lister les groupes IOMMU de chaque device (le GPU doit être seul dans son groupe)
find /sys/kernel/iommu_groups/ -type l 

# Résultats pour ma GTX 1650
# /sys/kernel/iommu_groups/1/devices/0000:00:01.0
# /sys/kernel/iommu_groups/1/devices/0000:01:00.0
#/sys/kernel/iommu_groups/1/devices/0000:01:00.1
```



## Etape 3 : Ajouter des modules VFIO (Virtual Function I/O) au noyau Linux

```bash
# Ajouter les modules suivants
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
echo "vfio_virqfd" >> /etc/modules

nano /etc/modules # Pour vérifier

# Identifier le vendor id : device id de ma carte graphique 
lspci -n -s 01:00

# Résultats pour ma GTX 1650
# 01:00.0 0300: 10de:1f82 (rev a1)
# 01:00.1 0403: 10de:10fa (rev a1)

# Executer les commandes suivantes pour empecher le host d'utiliser ce gpu
echo "options vfio-pci ids=10de:1f82,10de:10fa disable_vga=1" >> /etc/modprobe.d/vfio.conf

# Blacklister les drivers afin de forcer l'utilisation des drivers vfio
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf 
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf 

# MAJ initramfs
update-initramfs -u -k all

# Redemarrer Proxmox
reboot

# Verifier que le GPU utilise bien les drivers vfio
lspci -k


```



## Etape 4 : vérifier IOMMU Interrupt remapping

```bash
dmesg | grep 'remapping'
```



## Etape 5 : créer VM Win10

### Prérequis

1- Avoir chargé un ISO de Win10 sur un volume de son hôte proxmox



### Les paramètres importants :

##### Penser à activer les paramètres avancés 

##### Onglet OS

1- Indiquer l'image ISO de Win10

2- Type d'OS = Microsoft Windows

3- Version = 10/2016/2019

##### Onglet Système

1- Carte graphique = Défaut

2- Agent QEMU = true

3- Bios = ovmf (uefi)

4- Renseigner un volume pour la partition UEFI

5- Machine = q35 --> pour permettre la gestion du PCI Express

##### Onglet disque dur

1- Bus = SATA

2- Taille = A votre convenance

3- Cache = Write back

4- Discard = true --> si votre volume est sur un SSD

##### Onglet CPU

1- Nombre de coeurs : 4 (ou +)

##### Onglet mémoire

1- Mémoire : 4096 Mo (ou +)

##### Onglet réseau

1- Bridge = vmbr0

2- Modèle = Intel E1000



### L'installation de Win10

Cf. vidéo



### L'installation des Windows VirtIO Drivers

Depuis la VM, télécharger la dernière version disponible

https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso

Ouvrir l'ISO et exécuter les programmes suivants

```
virtio-win-gt-x64.msi
virtio-win-guest-tools
```



### L'activation du bureau à distance

Depuis la VM, dans Paramètres > Système > Bureau à distance, on active le bureau à distance et on note le nom du PC



## Etape 6 : personnaliser la VM Win10

Dans l'onglet matériel, on modifie le modèle de carte réseau par VirtIO

On en profite également pour retirer l'ISO de Windows

Enfin, on se connecte en SSH à notre hôte Proxmox pour éditer la configuration de la VM

```bash
# Edition de la configuration de la VM (101 dans mon cas)
nano /etc/pve/qemu-server/101.conf

# contenu du fichier 'origine'
balloon: 2048
bios: ovmf
boot: order=sata0;ide2;net0
cores: 4
efidisk0: vms:100/vm-100-disk-1.qcow2,size=128K
hostpci0: 01:00,pcie=1,x-vga=on
ide2: vms:iso/Win10_1909_French_x64.iso,media=cdrom
machine: pc-q35-5.2
memory: 4096
name: pve-win10
net0: e1000=BA:FE:8D:B8:04:16,bridge=vmbr0,firewall=1
numa: 0
ostype: win10
sata0: vms:100/vm-100-disk-0.qcow2,cache=writeback,size=32G
scsihw: virtio-scsi-pci
smbios1: uuid=8199783e-a724-465b-9783-c4b9944f203b
sockets: 1
vmgenid: 34ce9633-cbc9-4858-8472-794e10deb63f

# Ajouter les deux lignes suivantes après le nombre de cores
echo "cpu: host,hidden=1,flags=+pcid" >> /etc/pve/qemu-server/101.conf
echo "hostpci0: XX:XX,pcie=1,x-vga=on" >> /etc/pve/qemu-server/101.conf #Remplacer XX:XX par les PCI IDs de la carte graphique (lspci -v)
# Dans mon cas 
# echo "hostpci0: 01:00,pcie=1,x-vga=on" >> /etc/pve/qemu-server/101.conf

```



## Etape 7 :  installation de Parsec

### Se connecter au bureau distant

### Activer l'autologon dans Win10

Ouvrir **regedit**

Rechercher l'entrée du registre suivant

````
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device
````

Modifier la valeur de la clef **DevicePasswordLessBuildVersion** à 0 (au lieu de 2)

Ouvrir **netplwiz**, sélectionner votre utilisateur et désactiver l'option requérant le user/mdp pour le login



### Installer Parsec

Depuis la VM, se connecter sur https://parsec.app/ et télécharger la version pour Windows 64 bits

L'installer et créer un compte si vous n'en avez pas

Une fois connecté dans Parsec, sélectionner Settings > Host et activer "Machine lever user"



Installer également Parsec sur la machine invitée et vérifier dans Settings > Client que Overlay est sur Off



**NB : pour que Parsec fonctionne, il faut également installer sur votre hôte un petit dongle HDMI qui simule un écran pour votre carte graphique**

Voici le modèle que j'ai acheté pour 10€ sur Amazon

EZDIY-FAB HDMI Displayport Dummy Plug Émulateur d'affichage pour Les PC sans tête, BTC/ETH Mining Rig, 4096x2160 @ 60Hz, 1-Pack

https://www.amazon.fr/dp/B07BCCTWMX/ref=cm_sw_em_r_mt_dp_WH8X7DAWB7P6BZSWYJG2











