#!/bin/bash

# Script pour créer un conteneur LXC sous Proxmox, installer podman et configurer Vaultwarden
# Source : https://github.com/dani-garcia/vaultwarden
# Configuration :
# - Template : debian-13
# - Nom : ct-deb-vaultwarden
# - Disque : 4G
# - CPU : 1
# - RAM : 512M
# - Réseau : DHCP sur vmbr0
# - Podman : installé via apt

# Fonctions communes
source /opt/scripts/0-commons.sh

set -e  # Arrêter en cas d'erreur

# Variables configurables
HOSTNAME="ct-deb-vaultwarden"               # Nom d'hôte
PASSWORD="motdepasse"                       # Mot de passe root
STORAGE="local-lvm"                         # Stockage Proxmox
STORAGE_TEMPLATE="nfs1-no-raid"             # Stockage pour les templates. Defaut = local
CORES="1"                                   # Nombre de cœurs CPU
MEMORY="512"                                # Mémoire en MB
SWAP="512"                                  # Swap en MB
DISK_SIZE="4"                               # Taille du disque en Go
NET_BRIDGE="vmbr0"                          # Interface réseau
TEMPLATE_NAME=""                            # Modèle Debian 13

echo_blue "=== Création du conteneur LXC pour Vaultwarden ==="

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

# Générer le token admin
generate_argon2_hash
echo_blue "Token admin généré."

# Installer Vaultwarden dans le conteneur Podman via un quadlet
echo_blue "Installation de Vaultwarden..."
pct exec $CT_NEXT_ID -- bash -c "cat > /etc/containers/systemd/vaultwarden.container <<EOF
[Unit]
Description=Vaultwarden Container
Wants=network-online.target
After=network-online.target

[Container]
Image=docker.io/vaultwarden/server:latest 
ContainerName=vaultwarden
AutoUpdate=registry
PublishPort=80:80/tcp
Environment=SIGNUPS_ALLOWED=true
Environment= ADMIN_TOKEN=${ADMIN_TOKEN}
Volume=vaultwarden-data:/data

[Service]
Restart=always

[Install]
WantedBy=default.target
EOF"

# Rappel
echo_blue "Le volume est géré dans /var/lib/containers/storage/volumes/vaultwarden-data/_data"

# Activer et démarrer le service Vaultwarden
echo_blue "Activation et démarrage du service Vaultwarden..."
pct exec $CT_NEXT_ID -- bash -c "systemctl daemon-reload && systemctl start vaultwarden.service && systemctl status vaultwarden.service"

# Vérifier que le conteneur Podman fonctionne
echo_blue "Vérification de l'installation de Vaultwarden..."
pct exec $CT_NEXT_ID -- bash -c "podman ps"

# Récupérer l'adresse IP du conteneur
CT_IP=$(pct exec $CT_NEXT_ID -- hostname -I | awk '{print $1}')

echo_blue "=== Conteneur créé avec succès ==="
echo_blue "ID : $CT_NEXT_ID"
echo_blue "Nom : $HOSTNAME"
echo_blue "Pour accéder : pct enter $CT_NEXT_ID"
echo_blue "Pour arrêter : pct stop $CT_NEXT_ID"
echo_blue "Pour se connecter à Vaultwarden, passez imperativement par votre reverse proxy : https://$CT_IP"