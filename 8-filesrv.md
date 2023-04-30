# Création d'un conteneur LXC debian 11 pour serveur de fichier



## Tutoriel vidéo

[Lien vers la vidéo](https://youtu.be/ZnjVpdUOjPU)

## Téléchargement du template

Utilisation du template debian-11-standard

## Création du conteneur LXC

Création du rootfs de 8Go

Création d'un point de montage mp0  de 2200 Go sur /srv/samba/data en décochant l'option backup

Création d'un point de montage mp1  de 2200 Go sur /srv/samba/data-backup en décochant l'option backup

Au niveau du paramétrage DNS, renseigner home en DNS domain

Après le 1er démarrage du conteneur

- Activer Start at boot et le régler en 1er

## Maj système

```bash
# Maj système
apt update
apt full-upgrade -y

# Maj le fuseau horaire
dpkg-reconfigure tzdata
```

## Paramétrage SSH

```bash
# On créé le fichier de configuration
nano /etc/ssh/sshd_config.d/my-config.conf
```

Contenu du fichier :

```
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
usermod -G ssh,sudo christophe

# On se connecte avec cet utilisateur
su - christophe
```

## Sécurisation SSH

```bash
# On sécurise la connexion ssh en empêchant le login root
sudo nano /etc/ssh/sshd_config.d/my-config.conf
```

On modifie la ligne suivante :

```
PermitRootLogin no
```

```bash
# On relance le serveur SSH
sudo service ssh restart

# Donner le droit de ping aux utilisateurs autres que root
sudo setcap cap_net_raw+p /bin/ping
```

## Création partage SAMBA

### Installation de SAMBA

```bash
# Vérification si le daemon est déjà installé
sudo systemctl status smbd

# Si absent
sudo apt update
sudo apt install samba -y

# On stop le daemon
sudo systemctl stop smbd
```

### Edition du fichier de configuration

```bash
# On créé un backup
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

# On édite le fichier et on le remplace avec le contenu ci-après
sudo nano /etc/samba/smb.conf
```

```
[global]
workgroup = WORKGROUP
security = user
map to guest = Bad User
name resolve order = bcast host

[media]
comment = Partage Media sur HP Gen8
path = /srv/samba/data/media
force user = smbuser
force group = smbgroup
force create mode = 0664
force directory mode = 0775
browsable = yes
public = yes
writable = yes
```

### Création du user / group SAMBA

```bash
# Création du groupe système smbgroup
sudo groupadd --system smbgroup

# Création de l'utilisateur system smbuser
sudo useradd --system --no-create-home --group smbgroup --shell /sbin/nologin smbuser
```

### Création des répertoires de partage

```bash
sudo mkdir -p /srv/samba/data/media

# On attribue la propriété du répertoire à smbuser:smbgroup
sudo chown -R smbuser:smbgroup /srv/samba/data/media

# On change les droits en écriture pour le group smbgroup sur ce répertoire
sudo chmod -R g+w /srv/samba/data/media
```

### On relance le daemon

```
sudo systemctl start smbd
sudo systemctl status smbd
```

## Sauvegarde des données vers samba/data-backup 

```bash
# On installe rsync
sudo apt install rsync

# On synchronise les données des répertoire samba/data (source) vers samba/data-backup (destination)
# On teste la synchro
sudo rsync --dry-run --archive --delete --verbose /srv/samba/data/media /srv/samba/data-backup/

# Si OK, on entre les commandes dans un script qui sera executé via CRON par root
su -
touch /root/backup.sh
nano /root/backup.sh
```

Contenu du script

```bash
#!/bin/bash

echo "Debut du traitement $(date '+%Y-%m-%d %H:%M:%S')"

rsync --archive --delete /srv/samba/data/media /srv/samba/data-backup/

echo "Fin du traitement $(date '+%Y-%m-%d %H:%M:%S')"
```

On rend ce script executable et on le lance

```
chmod +x /root/backup.sh
bash /root/backup.sh
```

On le planifie dans CRON de l'utilisateur root

```
crontab -e
```

Contenu du crontab

```
# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  *  user command to be executed

# Execute le script de backup tous les jours 6h30
30  6  *  *  *  /root/backup.sh >> /root/backup.log
```

