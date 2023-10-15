# Création d'un conteneur LXC gérant l'accélération matérielle de mon iGPU pour Jellyfin

## Tutoriel vidéo

[Lien vers la vidéo](https://youtu.be/Vqr-0fI-99A)

## Téléchargement du template

Utilisation du template debian-12-standard

## Création du conteneur LXC

Bien décocher "conteneur non privilégié"

Création du rootfs de 8Go

Configuration du conteneur avec 2 coeurs, 2Go de RAM

Au niveau du paramétrage DNS, renseigner home en DNS domain

Après le 1er démarrage du conteneur

- Activer Start at boot
- Activer l'option "SMB/CIFS"

## Modification du fichier de configuration du conteneur LXC

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

Dans mon cas, le numéro majeur est 226 dans les 2 cas et les numéros mineurs sont 0 et 128


### Modification de la configuration du conteneur pour lui donner accès à l'iGPU de mon HOST

- Sur le HOST PVE, éditer le fichier `/etc/pve/lxc/<ID>.conf` avec votre editeur préféré (nano, vim ...)

- Ajouter les lignes suivantes :

```text
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/dri/card0 dev/dri/card0 none bind,optional,create=file,mode=0666
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
lxc.autodev: 1
```

Vous devrez ensuite redémarrer le conteneur pour que les modifications s'appliquent dans ce dernier.

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

## Ajouter du groupe sgx à l'utilisateur jellyfin 
On ajoute le groupe sgx à l'utilisateur jellyfin car ce groupe peut accéder aux devices vidéos

```bash
ls -lha /dev/dri
usermod -aG sgx jellyfin
```

On redémarrez le conteneur
```bash
reboot
```

## Se connecter à jellyfin

Dans son navigateur, entre l'URL http://<localIP>:8096

Dans le tableau de bord / Lecture :
1) Sélectionner l'accélération matérielle VAAPI
2) Paramétrer l'appareil VA-API `/dev/dri/renderD128`
3) Activer le transcodage matériel pour les codecs suivants : H264, HEVC, MPEG2, VC1, HEVC10 bits
4) Sauvegarder