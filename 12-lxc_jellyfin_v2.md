# Création d'un conteneur LXC gérant l'accélération matérielle de mon iGPU pour Jellyfin

Dans cette v2, nous utiliserons un conteneur LXC `unpriviledged`

## Identification de l'ID des groupes `video` et `render` sur mon HOST

On se connecte en SSH sur son HOST Proxmox

```bash
grep video /etc/group
grep render /etc/group
```

Retour terminal :

```text
video:x:44:
render:x:104:
```

Les ID sont donc 44 et 104

## Mapping de l'utilisateur `root`sur mon HOST

On édite le fichier `/etc/subgid` pour ajouter les 2 lignes suivantes :

```text
root:44:1
root:104:1
```

Dans la ligne `root:44:1`

* root est le nom de l'utilisateur principal auquel cette entrée s'applique.
* 44 est le premier GID alloué pour cet utilisateur.
* 1 est le nombre de GIDs alloués.

Cela signifie que pour l'utilisateur root, un bloc de GIDs commencera à 44 et se poursuivra sur une plage de 1. Cette information est utilisée par le gestionnaire de conteneurs pour attribuer des GIDs à des processus de conteneurs associés à l'utilisateur root.

## Téléchargement du template

Sur son hote Proxmox, executer la commande suivante :

```bash
# Mise à jour des templates
pveam update
```

On utilisera le template debian-12-standard

## Création du conteneur LXC

Bien laisser coché "conteneur non privilégié"

Création du rootfs de 8Go, en sélectionnant l'option de montage `noatime`

Configuration du conteneur avec 2 coeurs, 2Go de RAM

Au niveau du paramétrage Réseau, sélectionner `DHCP` pour IPv4

Au niveau du paramétrage DNS, renseigner `home` en DNS domain

Après le 1er démarrage du conteneur, activer l'option `Start at boot`

##  Modification du fichier de configuration du conteneur LXC

### Identification des numéros majeurs et mineurs des fichiers spéciaux associés aux périphériques de rendu

Sur le HOST, on exécute la commande suivante :

```bash
ls -l /dev/dri
```

Retour terminal :

```text
crw-rw---- 1 root video  226,   0 Sep 30 22:08 card0
crw-rw---- 1 root render 226, 128 Sep 30 22:08 renderD128
```

Dans mon cas, il n'y a qu'un seul GPU (iGPU de mon processeur)

### Modification de la configuration du conteneur pour lui donner accès à l'iGPU de mon HOST

Sur le HOST PVE, éditer le fichier `/etc/pve/lxc/<ID>.conf` avec votre editeur préféré (nano, vim ...)

Ajouter les lignes suivantes :

```text
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
lxc.idmap: u 0 100000 65536
lxc.idmap: g 0 100000 44
lxc.idmap: g 44 44 1
lxc.idmap: g 45 100045 61
lxc.idmap: g 106 104 1
lxc.idmap: g 107 100107 65429
lxc.autodev: 1
```

`lxc.idmap: u 0 100000 65536` signifie que dans le conteneur, les UID 0 à 65535 (65536 au total) seront mappés aux UID 100000 à 165535 de l'hôte. Cela est souvent utilisé pour éviter les conflits entre les UID du conteneur et de l'hôte, garantissant ainsi une isolation des identifiants utilisateur entre le conteneur et l'hôte.

`lxc.idmap: g 0 100000 44` signifie que dans le conteneur, les GID 0 à 43 seront mappés aux GID 100000 à 100043 de l'hôte. Cette configuration est également utilisée pour éviter les conflits de GID entre le conteneur et l'hôte, assurant ainsi une isolation des identifiants de groupe

`lxc.idmap: g 44 44 1` signifie que dans le conteneur, le GID 44 sera mappé au GID 44 de l'hôte.

`lxc.idmap: g 45 100045 61` signifie que dans le conteneur, les GIDs 45 à 105 seront mappés aux GIDs 100045 à 100105 de l'hôte. En effet, dans mon conteneur LXC, le GID du group `render` est `106`

`lxc.idmap: g 106 104 1` signifie que dans le conteneur, le GID 106 sera mappé au GID 104 de l'hôte.

`lxc.idmap: g 107 100107 65429` signifie que dans le conteneur, les GIDs 107 à 65535 seront mappés aux GIDs 100107 à 165635 de l'hôte.

Vous pouvez enfin démarrer le conteneur.

## Installation de VAINFO et des drivers MESA sur mon HOST

```bash
apt install vainfo mesa-va-drivers
```

On execute ensuite `vainfo` pour vérifier le bon fonctionnement

## Maj système sur le conteneur

```bash
# Maj système
apt update
apt full-upgrade -y

# Maj le fuseau horaire
dpkg-reconfigure tzdata

# Installation du sudo et curl
apt install sudo curl -y
```

## Installation de Jellyfin

Suivre les instructions disponibles [ici :](https://jellyfin.org/docs/general/installation/linux#debian)

```bash
curl https://repo.jellyfin.org/install-debuntu.sh | bash
```

## Téléchargement du film de test

```bash
mkdir /films
cd /films
curl -O https://download.blender.org/peach/bigbuckbunny_movies/big_buck_bunny_1080p_h264.mov
```

## Se connecter à jellyfin

Dans son navigateur, entre l'URL <http://localIP:8096>

Dans le tableau de bord / Lecture :

1) Sélectionner l'accélération matérielle VAAPI
2) Paramétrer l'appareil VA-API `/dev/dri/renderD128`
3) Activer le transcodage matériel pour les codecs suivants : H264, HEVC, MPEG2, VC1, HEVC10 bits
4) Sauvegarder

## Suppression des fichiers temporaires de transcodage

[Lien vers la vidéo](https://youtu.be/me6uCYqj1_Q)

Se connecter en SSH sur le conteneur en tant que root et crée le script bash `delete_ts_files.sh` suivant :

```txt
#!/bin/bash

# Specify the directory path
transcodes_directory="/var/lib/jellyfin/transcodes"

# Check if the directory exists
if [ -d "$transcodes_directory" ]; then
    # Delete .ts files in the specified directory
    find "$transcodes_directory" -type f -name "*.ts" -delete

    echo "Deleted .ts files in $transcodes_directory"
else
    echo "Error: Directory $transcodes_directory not found."
fi
```

Rendre ce script executable

```bash
chmod +x delete_ts_files.sh
```

Si besoin, planifier son execution dans cron

```bash
crontab -e
```

Pour une execution hebdomadaire chaque samedi à minuit

```text
0 0 * * 6 /root/delete_ts_files.sh
```

## Accéder à un partage CIFS depuis un conteneur LXC unpriviledged

L'idée est de monter le partage CIFS sur l'hote Proxmox et de le partager avec le conteneur LXC via un point de montage

### Création du groupe lxc_samba sur le conteneur

On commence par créer ce groupe lxc_samba en lui attribuant le GID 10000

```bash
groupadd -g 10000 lxc_samba
```

### Ajout de ce groupe à l'utilisateur jellyfin sur le conteneur

```bash
usermod -aG lxc_samba jellyfin
```

### Création du point de montage CIFS sur l'hote Proxmox

```bash
mkdir -p /mnt/lxc/videos
```

### Montage du partage CIFS sur l'hote Proxmox

On ajoute la configuration suivante au fichier `/etc/fstab`

```text
# Montage du partage CIFS disponible sur mon NAS
//NAS-IP-ADDRESS/media/videos /mnt/lxc/videos cifs _netdev,x-systemd.automount,noatime,uid=100000,gid=110000,dir_mode=0770,file_mode=0770,user=smb_username,pass=smb_password,vers=3.0 0 0
```

Quelques explications :

* `//NAS-IP-ADDRESS/media/videos` : Il s'agit du chemin distant du partage CIFS que vous souhaitez monter.

* `/mnt/lxc/videos` : C'est le point de montage local où le partage CIFS sera monté.

* `cifs` : Cela indique le type de système de fichiers, qui est CIFS dans ce cas.

* `_netdev` : Cette option indique au système qu'il s'agit d'un périphérique réseau et qu'il doit être monté après que le réseau soit disponible.

* `x-systemd.automount` : C'est une option spécifique à systemd pour le montage automatique.

* `noatime` : Cette option désactive la mise à jour de l'heure d'accès à chaque lecture.

* `uid=100000` : Définit l'identifiant d'utilisateur (UID) pour toutes les opérations sur le système de fichiers.

* `gid=110000` : Définit l'identifiant de groupe (GID) pour toutes les opérations sur le système de fichiers. Dans notre cas, cela correspond au groupe `10000` sur le conteneur.

* `dir_mode=0770` : Définit les permissions pour les répertoires sur le système de fichiers monté.

* `file_mode=0770` : Définit les permissions pour les fichiers sur le système de fichiers monté.

* `user=smb_username` : Spécifie le nom d'utilisateur à utiliser lors de la connexion au partage CIFS.

* `pass=smb_password` : Spécifie le mot de passe à utiliser lors de la connexion au partage CIFS.

* `vers=3.0` : Spécifie la version du protocole CIFS.

* `0 0` : Ce sont les options de sauvegarde du système de fichiers et de vérification du système de fichiers. Elles sont généralement définies à 0 pour les systèmes de fichiers réseau.

On monte la nouvelle configuration du fichier `/etc/fstab`

```bash
mount -a
```

### Partage de ce point de montage avec le conteneur LXC

Eteindre le conteneur LXC au préalable

```bash
pct stop <ID_conteneur>
```

On edite le fichier `/etc/pve/lxc/<ID>.conf` pour ajouter le point de montage :

```text
mp0: /mnt/lxc/videos,mp=/mnt/videos
```

On redémarre le conteneur LXC

```bash
pct start <ID_conteneur>
```
