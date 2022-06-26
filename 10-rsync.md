# Backup via Rsync



## Installation de Rsync

```bash
# Sur mon serveur hôte (i.e. le conteneur LXC deb11 docker), on installe rsync
sudo apt update
sudo apt install rsync -y
```



## Backup de la config Docker

```bash
# Sur mon serveur distant (le conteneur LXC deb11 filesrv pour l'exemple), je crée le repertoire de backup
sudo mkdir -p /srv/rsync/docker-data-backup

# J'attribue la propriéte de ce répertoire à mon user christophe
sudo chown -R christophe:christophe /srv/rsync/docker-data-backup

# On tester la synchro depuis l'hôte
sudo touch /srv/docker-data/test1.txt
sudo rsync --dry-run --verbose --archive --compress --delete --progress /srv/docker-data/ christophe@lxc-deb11-filesrv-test.home:/srv/rsync/docker-data-backup

# Si OK, on met en place l'authentification par certificat entre l'hote et la destination
# Sur l'hôte, on se connecte en root
su -

# On génère une clef d'authentification
ssh-keygen -t rsa -b 4096 -C "root@lxc-dev11-docker-test"

# On copie la clef publique sur l'hote distant
ssh-copy-id -i /root/.ssh/id_rsa.pub christophe@lxc-deb11-filesrv-test.home

# On teste la connexion
ssh christophe@lxc-deb11-filesrv-test.home

# Puis on entre les commandes de synchro dans un script qui sera executé via CRON par root
touch /root/backup.sh
nano /root/backup.sh
```

Contenu du script

```bash
#!/bin/bash

echo "Debut du traitement $(date '+%Y-%m-%d %H:%M:%S')"

sudo rsync --archive --compress --delete --progress /srv/docker-data/ christophe@lxc-deb11-filesrv-test.home:/srv/rsync/docker-data-backup

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

# Execute le script de backup tous les jours 6h30 GMT
30  6  *  *  *  /root/backup.sh >> /root/backup.log
```







