# Création d'un conteneur LXC gérant l'accélération matérielle de mon iGPU pour Jellyfin

## Tutoriel vidéo

[Lien vers la vidéo](https://xxx)

## Téléchargement du template

Utilisation du template debian-12-standard

## Création du conteneur LXC

Bien décocher "conteneur non privilégié"

Création du rootfs de 8Go

Configuration du conteneur avec 4 coeurs, 2Go de RAM

Création d'un point de montage mp0 sur /srv/docker-data en décochant l'option backup

Au niveau du paramétrage DNS, renseigner home en DNS domain

Après le 1er démarrage du conteneur

- Activer Start at boot
- Activer les features "Nesting" et "SMB/CIFS"

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

## Installation de VAINFO et des drivers MESA sur mon HOST

```bash
sudo apt install vainfo mesa-va-drivers
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




## Paramétrage SSH sur le conteneur

```bash
# On créé le fichier de configuration
nano /etc/ssh/sshd_config.d/my-config.conf
```

Contenu du fichier :

```text
Port 22

# Logging
SyslogFacility AUTH
LogLevel INFO

# Authentication
LoginGraceTime 2m
PermitRootLogin yes
AllowGroups root ssh
PermitEmptyPasswords no
StrictModes yes
MaxAuthTries 6
MaxSessions 10
PubkeyAuthentication yes

X11Forwarding yes
X11DisplayOffset 10
```

```bash
# On relance le serveur SSH
service ssh restart
```

## Installation de la commande sudo

```bash
apt install sudo -y
```

## Création d'un utilisateur

```bash
# Création de l'utilisateur
adduser christophe

# Ajout de groupes à l'utilisateur
usermod -aG ssh,sudo christophe

# On se connecte avec cet utilisateur
su - christophe
```

## Sécurisation SSH

```bash
# On sécurise la connexion ssh en empêchant le login root
sudo nano /etc/ssh/sshd_config.d/my-config.conf
```

On modifie la ligne `PermitRootLogin no`


```bash
# On relance le serveur SSH
sudo service ssh restart
```



Préférer le conteneur de média fMP4-HLS

usermod -aG sgx jellyfin