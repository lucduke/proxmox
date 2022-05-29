# Création d'un conteneur LXC debian 11 pour docker



## Téléchargement du template

Utilisation du template debian-11-standard

## Création du conteneur LXC

Bien décocher "conteneur non privilégié"

Création du rootfs de 20Go

Création d'un point de montage mp0  de 220 Go sur /srv/docker-data en décochant l'option backup

Au niveau du paramétrage DNS, renseigner home en DNS domain

Après le 1er démarrage du conteneur

- Activer Start at boot
- Activer les features "Nesting" et "SMB/CIFS"

## Maj système

```bash
# Maj système
apt update
apt full-upgrade -y
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
```

## Installation de Docker

Source : https://docs.docker.com/engine/install/debian/

```bash
# On desinstalle les éventuels anciens paquets
sudo apt remove docker docker.io containerd runc

# On ajoute le dépôt Docker
sudo apt install ca-certificates curl gnupg lsb-release -y
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# On installe le docker engine
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

# On teste le bon fonctionnement
sudo docker run hello-world
```

## Installation de Portainer

```bash
# On installe
sudo docker volume create portainer_data
sudo docker run -d -p 8000:8000 -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
```

On teste la connexion : http://deb11-lxc-docker.home:9000/#/auth

On personnalise l'environnement local

On créé 2 réseaux bridge

- christophe_frontend
- christophe_backend

## Chargement partages CIFS 

```bash
# Installation de cifs-utils
sudo apt install cifs-utils -y

# Création du point de montage
sudo mkdir -p /mnt/media
sudo mkdir -p /mnt/documents
sudo mkdir -p /mnt/docker-data-backup

# Edition du fstab
sudo nano /etc/fstab
```

On ajoute la ligne suivante

```
//deb11-lxc-filesrv.home/media /mnt/media cifs _netdev,guest,exec,dir_mode=0775,file_mode=0664,uid=1000,gid=1000 0 0
//rpi4-chris.home/docker-data-backup /mnt/docker-data-backup cifs _netdev,guest,exec,dir_mode=0775,file_mode=0664,uid=1000,gid=1000 0 0
```

On monte le partage

```bash
sudo mount -a
```

## Backup de la config Docker

```bash
# On installe rsync
sudo apt install rsync -y

# On tester la synchro
sudo rsync --dry-run --archive --delete --verbose /srv/docker-data/ /mnt/docker-data-backup/

# Si OK, on entre les commandes dans un script qui sera executé via CRON par root
su -
touch /root/backup.sh
nano /root/backup.sh
```

Contenu du script

```bash
#!/bin/bash

echo "Debut du traitement $(date '+%Y-%m-%d %H:%M:%S')"

rsync --archive --delete /srv/docker-data/ /mnt/docker-data-backup/

echo "Fin du traitement $(date '+%Y-%m-%d %H:%M:%S')"
```

On rend ce script executable et on le lance

```bash
chmod +x /root/backup.sh
bash /root/backup.sh
```

On le planifie dans CRON de l'utilisateur root

```bash
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







