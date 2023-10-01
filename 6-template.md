# Création template VM



Dans cet article, nous allons voir comment créer un template qui nous permettra de créer des clones de machines virtuelles. Dans cet exemple, les clones seront des machines virtuelles basées sur debian 11.


## Tutoriel vidéo
[lien](https://youtu.be/7ToFpdpPVHE)


## Téléchargement ISO Debian 11

```
https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/debian-11.0.0-amd64-DVD-1.iso
```



## Ajout de programmes

```bash
apt install -y htop qemu-guest-agent sudo cloud-init
```



## Ajout de sudo à mon user

```bash
# En root
# On ajoute le groupe sudo à mon utilisateur
usermod -aG sudo christophe

# On redemarre
reboot
```


## Installation de Docker

```bash
# Source: https://docs.docker.com/engine/install/debian/
# On supprime de potentielles anciennes installations
sudo apt update
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done

# On installe les paquets nécessaires
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
sudo apt install


# On ajoute la clef GPG officielle de Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# On ajoute le dépôt
echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# On installe docker engine
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run hello-world

# On installe docker-compose
# Source: https://docs.docker.com/compose/install/
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```



## Installation de Portainer (local volume)

```bash
sudo docker volume create portainer_data

sudo docker run -d -p 8000:8000 -p 9000:9000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data --label com.centurylinklabs.watchtower.enable=true portainer/portainer-ce:latest

# Pour se connecter: http://<ip_server>:9000/
```

## Installation de Portainer (nfs volume)

```bash
sudo docker volume create --driver local --opt type=nfs --opt o=addr=nas.home,rw,nfsvers=4 --opt device=:/srv/raid/nfs/docker/portainer_nfs_data portainer_nfs_data

sudo docker run -d -p 8000:8000 -p 9000:9000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_nfs_data:/data --label com.centurylinklabs.watchtower.enable=true portainer/portainer-ce:latest

# Pour se connecter: http://<ip_server>:9000/
```



## Anonymisation de la VM

```bash
# Suppression des clefs SSH
sudo rm /etc/ssh/ssh_host_*

# Suppression du machine-id
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Nettoyage base apt
sudo apt clean
sudo apt autoremove

# Nettoyage de l'historique des commandes sur le compte root et utilisateur.
history -c

# Extinction VM
sudo poweroff
```



## Quelques étapes avant de convertir la VM en template

1- Enlever le CD-ROM dans l'onglet matériel


## Cloud-init

Pour faciliter la personnalisation des clones du template, on peut venir attacher à ce dernier un lecteur cloud-init

Dans l'onglet cloud-init associé au template, on peut ainsi créer par défaut un utilisateur particulier et son mot de passe, ajouter une clef publique SSH (pour faciliter la connexion en SSH) et définir la configuration réseau.

Une fois ces paramètres renseignés, il faut cliquer sur regénérer l'image

Au 1er démarrage du clone, cloud-init va mettre à jour le système, créer l'utilisateur sur la VM, regénérer les clefs SSH et personnaliser les fichiers hosts et hostnames en fonction du nom de la VM

[Le lien vers l'illustration en vidéo](https://youtu.be/xfOKS853aXI)


## Attention

Ne pas oublier de changer le nom d'hôte des VM crées à partir de ce template si vous n'utilisez pas cloud-init

```bash
sudo nano /etc/hostname
sudo nano /etc/hosts
```

Regenerer les clefs SSH

```bash
sudo dpkg-reconfigure openssh-server
```

