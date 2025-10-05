#!/bin/bash

# Script pour créer un conteneur LXC sous Proxmox, installer podman et configurer Cloudflare
# Source : https://one.dash.cloudflare.com
# Configuration :
# - Template : debian-13
# - Nom : ct-deb-cloudflare
# - Disque : 4G
# - CPU : 1
# - RAM : 512M
# - Réseau : DHCP sur vmbr0
# - Podman : installé via apt

# Fonctions communes
source /opt/scripts/0-commons.sh

set -e  # Arrêter en cas d'erreur

# Variables configurables
HOSTNAME="ct-deb-cloudflare"               # Nom d'hôte
PASSWORD="motdepasse"                       # Mot de passe root
STORAGE="local-lvm"                         # Stockage Proxmox
STORAGE_TEMPLATE="nfs1-no-raid"             # Stockage pour les templates. Defaut = local
CORES="1"                                   # Nombre de cœurs CPU
MEMORY="512"                                # Mémoire en MB
SWAP="512"                                  # Swap en MB
DISK_SIZE="4"                               # Taille du disque en Go
NET_BRIDGE="vmbr0"                          # Interface réseau
TEMPLATE_NAME=""                            # Modèle Debian 13
CLOUDFLARE_TUNNEL_TOKEN="votre_token_de_tunnel"  # Remplacez par votre token de tunnel Cloudflare

echo "=== Création du conteneur LXC pour Cloudflare ==="

# Vérifier si l'utilisateur est root
check_root

# Obtenir le prochain ID disponible
CT_NEXT_ID=$(pvesh get /cluster/nextid)
echo "ID du conteneur : $CT_NEXT_ID"

# Télécharger le template Debian 13 si nécessaire
download_template_if_needed

# Créer le conteneur
create_container

# Démarrer le conteneur
echo "Démarrage du conteneur..."
pct start $CT_NEXT_ID

# Attendre que le conteneur soit prêt
echo "Attente du démarrage..."
sleep 10

# Installer Podman dans le conteneur
echo "Installation de Podman..."
pct exec $CT_NEXT_ID -- bash -c "apt update && apt full-upgrade -y && apt install -y podman podman-compose"

# Installer cloudflared dans le conteneur Podman via un quadlets
echo "Installation de cloudflare..."
pct exec $CT_NEXT_ID -- bash -c "mkdir -p /etc/containers/systemd"
pct exec $CT_NEXT_ID -- bash -c "cat > /etc/containers/systemd/cloudflare.container <<EOF
[Unit]
Description=Cloudflare Container
After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/cloudflare/cloudflared:latest
ContainerName=cloudflare
Exec=tunnel --no-autoupdate run
AutoUpdate=registry
EnvironmentFile=/etc/cloudflare.env

[Service]
Restart=on-failure
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target default.target
EOF"

# Création du fichier .env pour Cloudflare
EnvironmentFile=/etc/cloudflare.env
pct exec $CT_NEXT_ID -- bash -c "cd /etc && cat > cloudflare.env <<EOF
# Token du tunnel Cloudflare
TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
EOF"

pct exec $CT_NEXT_ID -- bash -c "systemctl daemon-reload && systemctl start cloudflare.service && systemctl status cloudflare.service"

    # Vérifier que le conteneur Podman fonctionne
echo "Vérification de l'installation de Cloudflare..."
pct exec $CT_NEXT_ID -- bash -c "podman ps"

# Récupérer l'adresse IP du conteneur
CT_IP=$(pct exec $CT_NEXT_ID -- hostname -I | awk '{print $1}')

echo "=== Conteneur créé avec succès ==="
echo "ID : $CT_NEXT_ID"
echo "Nom : $HOSTNAME"
echo "Pour accéder : pct enter $CT_NEXT_ID"
echo "Pour arrêter : pct stop $CT_NEXT_ID"