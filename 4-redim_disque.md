# Etendre la taille de sa partition principale OMV



## Tutoriel vidéo





## Retrouver l'UUID de sa partition SWAP

Se connecter en SSH sur son serveur OMV

````bash
# Récupérer l'UUID de ses partition
blkid
# Dans mon cas le résultat est le suivant pour ma partition SWAP
# /dev/sda5: UUID="5844007e-b637-48c0-a974-5878ddec61b2" TYPE="swap" PARTUUID="ab604992-05"

/dev/sda5: UUID="647ae9ed-9991-4f79-9322-9faf270c619e" TYPE="swap" PARTUUID="a26bbb8c-05"
````



## Arrêter son serveur OMV

Cf. tutoriel vidéo



## Redimensionner le disque de la VM depuis l'interface graphique Proxmox

Cf. tutoriel vidéo



## Télécharger l'ISO de GPARTED

Se connecter en SSH sur son serveur Proxmox

````bash
cd /var/lib/vz/template/iso
wget https://downloads.sourceforge.net/gparted/gparted-live-1.2.0-1-amd64.iso
````



## Faire un snapshot

Cf. tutoriel vidéo



## Démarrer la VM OMV5 sur l'ISO GPARTED

Penser à charger l'ISO dans le lecteur CD/DVD virtuel et modifier l'ordre de boot 

Cf. tutoriel vidéo



## Utiliser GPARTED

Principales étapes

- On sélectionne sur disque sda
- On supprimer la partition logique linux-swap actuelle (4094 Mo)
- On supprimer la partition étendue
- On redimensionne la partition sda1
- On crée une nouvelle partition étendue
- On crée une nouvelle partition linux-swap
- On valide
- On quitte Gparted

Cf. tutoriel vidéo



## Démarrer la VM OMV5 

Penser à supprimer l'ISO dans le lecteur CD/DVD virtuel et modifier l'ordre de boot



## Assigner l'UUID de l'ancienne partition SWAP à la nouvelle

Se connecter en SSH sur son serveur OMV

````bash
# On constate la taille de la nouvelle partition
df -hT

# On constate l'absence de swap
free

# On constate le nouvel UUID assigné à la partition SWAP
blkid
# Dans mon cas le résultat est le suivant pour ma partition SWAP
# /dev/sda5: UUID="542739b2-3b8d-4e91-9218-1dfa24f810b5" TYPE="swap" PARTUUID="ab604992-05"

# On assigne l'UUID de l'ancienne partition SWAP à la nouvelle
mkswap -U "5844007e-b637-48c0-a974-5878ddec61b2" /dev/sda5

# On redemarre pour vérifier que tout va bien
reboot
````



