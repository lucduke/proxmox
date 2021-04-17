# Installation de Proxmox Virtual Environment



## Introduction

Série de scripts / commandes permettant de personnaliser l'installation de Proxmox Virtual Environment


## Liens vers la vidéo


## Installation à partir de l'ISO officiel
Le fichier ISO de Proxmox Virtual Environment est disponible en téléchargement sur le site de Proxox (  



## Maj les dépôts / désactivation du pop-up de souscription / optimisation du SWAP

### Lancer toutes ces actions par script (en root)

```bash
wget -q -O - https://raw.githubusercontent.com/lucduke/proxmox/main/pve-no-subscription.sh | bash
```



### Maj la source des paquets en mode manuel

```bash
# Editer la fichier contenant les sources de paquets ...
nano /etc/apt/sources.list.d/pve-enterprise.list
# Et commenter la ligne suivante en ajoutant # au début
deb https://enterprise.proxmox.com/debian/pve buster pve-enterprise

# Ajouter le dépôt pve-no-subscription
echo "deb http://download.proxmox.com/debian/pve buster pve-no-subscription" >> /etc/apt/sources.list
```



### Supprimer le pop-up en mode manuel

```bash
# Editer le scrip
nano /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# Rechercher No valid subscription
# Texte origine
Ext.Msg.show({
  title: gettext('No valid subscription'),

# Texte cible
void({ //Ext.Msg.show({
  title: gettext('No valid subscription'),
  
# Redemarrer Proxmox webservice
systemctl restart pveproxy.service
```



### Optimiser le swap en mode manuel

```bash
# Pour visualiser l'utilisation de la mémoire
free -m

# Pour visualiser le % d'utilisation de la mémoire à partir duquel le swap est activé
cat /proc/sys/vm/swappiness

# Pour modifier (ici swap quand il ne reste que 10% de la mémoire libre)
sysctl vm.swappiness=10
cat /proc/sys/vm/swappiness

# Désactiver / activer le swap pour prise en compte
swapoff -a
swapon -a

```



## Gestion du stockage

### Suppression du stockage par défaut local-lvm

Dans Datacenter > Stockage, on sélectionne le stockage "local-lvm" et on clique sur supprimer



### Création du volume logique pour les VMs

On sélectionne le serveur "pve" et on accède au Shell (ou alors conne)

```bash
# Lister les volumes group
vgs

# Lister les volumes logiques
lvs

# Supprimer le volume data dans le groupe pve
lvremove pve data

# Créer le volume logique vms (827Go dans mon exemple) dans le volume group pve
vgs # Pour visualiser l'espace disponible
lvcreate -n vms -L 827G pve

# Formater le nouveau volume en ext4
mkfs.ext4 /dev/pve/vms

# Monter le nouveau volume dans /mnt/vms
mkdir -p /mnt/vms
echo "/dev/pve/vms /mnt/vms ext4 defaults,discard 0 2" >> /etc/fstab
mount -a
df -h #pour vérifier le montage
```



On sélectionne le datacenter > Stockage, ajouter "Répertoire"



### Ajout de HDD supplémentaires

```bash
# Identifier le disque supplémentaire
lsblk

# Installer parted (permet de formater des disques > 2TB)
apt policy parted
apt install -y parted

# Créer une nouvelle table de partition GPT pour chacun des nouveaux disques
# Pour HDDA
parted /dev/sda mklabel gpt
# Pour HDDB
parted /dev/sdb mklabel gpt

# Créer une partition primaire qui fait 100% de chacun des nouveaux disques
# Pour HDDA
parted -a opt /dev/sda mkpart primary ext4 0% 100%
# Pour HDDB
parted -a opt /dev/sdb mkpart primary ext4 0% 100%

# Créer un nouveau volume de groupe LVM pour chacun des nouveaux disques
# Pour HDDA
vgcreate pve2-vg-sda /dev/sda1
# Pour HDDB
vgcreate pve2-vg-sdb /dev/sdb1

# Créer un volume logique pour le stockage des data
# Pour visualiser la taille des volume groups
vgs
# Pour HDDA (2.7 To dans mon exemple)
lvcreate -n data -L 2.7T pve2-vg-sda
# Pour HDDB (2.7 To dans mon exemple)
lvcreate -n data-backup -L 2.7T pve2-vg-sdb

# Formater le nouveau volume en ext4
# Pour HDDA
mkfs.ext4 /dev/pve2-vg-sda/data
# Pour HDDB
mkfs.ext4 /dev/pve2-vg-sdb/data-backup

# Monter le nouveau volume dans /mnt/data et /mnt/data-backup
mkdir -p /mnt/data
mkdir -p /mnt/data-backup
echo "/dev/pve2-vg-sda/data /mnt/data ext4 defaults 0 2" >> /etc/fstab
echo "/dev/pve2-vg-sdb/data-backup /mnt/data-backup ext4 defaults 0 2" >> /etc/fstab
mount -a
lsblk
df -h #pour vérifier le montage
```

On sélectionne ensuite le datacenter > Stockage, ajouter "Répertoire"



## Personnaliser bash

### Par script (en root)

```bash
wget -q -O - https://raw.githubusercontent.com/lucduke/proxmox/main/bash-custom.sh | bash
```
