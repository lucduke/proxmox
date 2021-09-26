# Création template VM



Dans cet article, nous allons voir comment créer un template qui nous permettra de créer des clones de machines virtuelles. Dans cet exemple, les clones seront des machines virtuelles basées sur debian 11.


## Tutoriel vidéo



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
sudo apt remove docker docker-engine docker.io containerd runc

# On installe les paquets nécessaires
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# On ajoute la clef GPG officielle de Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# On ajoute le dépôt
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# On installe docker engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io 
sudo docker run hello-world

# On installe docker-compose
# Source: https://docs.docker.com/compose/install/
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```



## Installation de Portainer

```bash
sudo docker volume create portainer_data
sudo docker run -d -p 8000:8000 -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce

# Pour se connecter: http://<ip_server>:9000/
```



## Anonymisation de la VM

```bash
# Suppression des clefs SSH
sudo rm sudo rm /etc/ssh/ssh_host_*

# Suppression du machine-id
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Nettoyage base apt
sudo clean apt
sudo apt autoremove

# Extinction VM
sudo poweroff
```



## Quelques étapes avant de convertir la VM en template

1- Enlever le CD-ROM dans l'onglet matériel



## Attention

Ne pas oublier de changer le nom d'hôte des VM crées à partir de ce template

```bash
sudo nano /etc/hostname
sudo nano /etc/hosts
```

Regenerer les clefs SSH

```bash
sudo dpkg-reconfigure openssh-server
```

