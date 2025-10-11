#!/bin/bash

# Script pour créer un conteneur LXC sous Proxmox, installer podman
# Source : 
# Configuration :
# - Template : debian-13
# - Nom : ct-deb-test
# - Disque : 4G
# - CPU : 1
# - RAM : 512M
# - Réseau : DHCP sur vmbr0
# - Podman : installé via apt

# Fonctions communes
source /opt/scripts/0-commons.sh

set -e  # Arrêter en cas d'erreur

# Variables configurables
HOSTNAME="ct-deb-test"                      # Nom d'hôte
PASSWORD="motdepasse"                       # Mot de passe root
STORAGE="local-lvm"                         # Stockage Proxmox
STORAGE_TEMPLATE="nfs1-no-raid"             # Stockage pour les templates. Defaut = local
CORES="1"                                   # Nombre de cœurs CPU
MEMORY="512"                                # Mémoire en MB
SWAP="512"                                  # Swap en MB
DISK_SIZE="4"                               # Taille du disque en Go
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

# Récupérer l'adresse IP du conteneur
CT_IP=$(pct exec $CT_NEXT_ID -- hostname -I | awk '{print $1}')

echo_blue "=== Conteneur créé avec succès ==="
echo_blue "ID : $CT_NEXT_ID"
echo_blue "Nom : $HOSTNAME"
echo_blue "Pour accéder : pct enter $CT_NEXT_ID"
echo_blue "Pour arrêter : pct stop $CT_NEXT_ID"