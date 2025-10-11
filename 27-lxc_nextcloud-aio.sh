#!/bin/bash

# Script pour créer un conteneur LXC sous Proxmox, installer podman et configurer Nextcloud AIO
# Source : https://nextcloud.com/blog/how-to-install-the-nextcloud-all-in-one-on-linux/
# Documentation : https://github.com/nextcloud/all-in-one#how-to-adjust-the-max-execution-time-for-nextcloud
# Configuration :
# - Template : debian-13
# - Nom : ct-deb-nextcloud-aio
# - Disque : 50G
# - CPU : 2
# - RAM : 2048M
# - Réseau : DHCP sur vmbr0
# - Podman : installé via apt

# Fonctions communes
source /opt/scripts/0-commons.sh

set -e  # Arrêter en cas d'erreur

# Variables configurables
HOSTNAME="ct-deb-nextcloud-aio"             # Nom d'hôte
PASSWORD="motdepasse"                       # Mot de passe root
STORAGE="local-lvm"                         # Stockage Proxmox
STORAGE_TEMPLATE="nfs1-no-raid"             # Stockage pour les templates. Defaut = local
CORES="2"                                   # Nombre de cœurs CPU
MEMORY="2048"                               # Mémoire en MB
SWAP="1024"                                 # Swap en MB
DISK_SIZE="50"                              # Taille du disque en Go
NET_BRIDGE="vmbr0"                          # Interface réseau
TEMPLATE_NAME=""                            # Modèle Debian 13

echo_blue "=== Création du conteneur LXC ==="

# Vérifier si l'utilisateur est root
check_root

# Obtenir le prochain ID disponible
CT_NEXT_ID=$(pvesh get /cluster/nextid)
echo_blue "ID du conteneur : $CT_NEXT_ID"

# Télécharger le template Debian 13 si nécessaire
download_template_if_needed

# Créer le conteneur
create_container

# Démarrer le conteneur
echo_blue "Démarrage du conteneur..."
pct start $CT_NEXT_ID

# Attendre que le conteneur soit prêt
echo_blue "Attente du démarrage..."
sleep 10

# Installer Podman dans le conteneur
echo_blue "Installation de Podman..."
pct exec $CT_NEXT_ID -- bash -c "apt update && apt full-upgrade -y && apt install -y podman"

# Installer Nextcloud AIO dans le conteneur Podman via un quadlet
echo_blue "Installation de Nextcloud AIO..."
pct exec $CT_NEXT_ID -- bash -c "cat > /etc/containers/systemd/nextcloud-aio.container <<EOF
[Unit]
Description=Nextcloud AIO Container
Wants=network-online.target
After=network-online.target

[Container]
Image=ghcr.io/nextcloud-releases/all-in-one:latest
ContainerName=nextcloud-aio-mastercontainer
AutoUpdate=registry
PublishPort=80:80
PublishPort=8080:8080
PublishPort=8443:8443
Environment=APACHE_PORT=11000
Environment=APACHE_IP_BINDING=0.0.0.0
Volume=nextcloud_aio_mastercontainer:/mnt/docker-aio-config
Volume=/run/podman/podman.sock:/var/run/docker.sock:ro
PodmanArgs=--init
PodmanArgs=--sig-proxy=false

[Service]
Restart=always

[Install]
WantedBy=default.target
EOF"

# Rappel
echo_blue "Le volume est géré dans /var/lib/containers/storage/volumes/nextcloud_aio_mastercontainer/_data"
echo_blue "Les données des utilisateurs seront stockées dans le répertoire /var/lib/containers/storage/volumes/nextcloud_aio_nextcloud_data/_data"
echo_blue "La configuration sera dans /var/lib/containers/storage/volumes/nextcloud_aio_mastercontainer/_data/data/configuration.json"

# Activer et démarrer le service Nextcloud AIO
echo_blue "Activation et démarrage du service Nextcloud AIO..."
pct exec $CT_NEXT_ID -- bash -c "systemctl enable --now podman.socket && systemctl daemon-reload && systemctl start nextcloud-aio.service && systemctl status nextcloud-aio.service"

# Récupérer l'adresse IP du conteneur
CT_IP=$(pct exec $CT_NEXT_ID -- hostname -I | awk '{print $1}')

echo_blue "=== Conteneur créé avec succès ==="
echo_blue "ID : $CT_NEXT_ID"
echo_blue "Nom : $HOSTNAME"
echo_blue "Pour accéder : pct enter $CT_NEXT_ID"
echo_blue "Pour arrêter : pct stop $CT_NEXT_ID"
echo_blue "Pour démarrer : pct start $CT_NEXT_ID"
echo_blue "Accéder à Nextcloud AIO via : https://$CT_IP:8080"
echo_blue "Configurer le tunnel cloudflare en référençant le port 11000"
echo_blue "Pour executer une commande occ : podman exec -it --user www-data nextcloud-aio-nextcloud php occ maintenance:repair --include-expensive"
