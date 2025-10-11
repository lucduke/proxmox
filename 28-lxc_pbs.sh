#!/bin/bash

# Script pour créer un conteneur LXC sous Proxmox, installer Proxmox PBS
# Source : https://www.proxmox.com/en/products/proxmox-backup-server/overview
# Documentation : https://pbs.proxmox.com/docs/
# Configuration :
# - Template : debian-13
# - Nom : ct-deb-pbs
# - Disque : 10G
# - CPU : 2
# - RAM : 4096 Mo
# - Réseau : DHCP sur vmbr0


# Fonctions communes
source /opt/scripts/0-commons.sh

set -e  # Arrêter en cas d'erreur

# Variables configurables
HOSTNAME="ct-deb-pbs"                       # Nom d'hôte
PASSWORD="motdepasse"                       # Mot de passe root
STORAGE="local-lvm"                         # Stockage Proxmox
STORAGE_TEMPLATE="nfs1-no-raid"             # Stockage pour les templates. Defaut = local
CORES="2"                                   # Nombre de cœurs CPU
MEMORY="4096"                               # Mémoire en MB
SWAP="1024"                                 # Swap en MB
DISK_SIZE="10"                              # Taille du disque en Go
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

# Créer le conteneur (privilégié)
create_container 0

# Démarrer le conteneur
echo_blue "Démarrage du conteneur..."
pct start $CT_NEXT_ID

# Attendre que le conteneur soit prêt
echo_blue "Attente du démarrage..."
sleep 10

# Configuration du depot Proxmox Backup Server en editant le fichier /etc/apt/sources.list.d/proxmox.sources
echo_blue "Configuration du dépôt Proxmox Backup Server..."
pct exec $CT_NEXT_ID -- bash -c "cat > /etc/apt/sources.list.d/proxmox.sources <<EOF
Types: deb
URIs: http://download.proxmox.com/debian/pbs
Suites: trixie
Components: pbs-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF"

# Ajouter la clé du dépôt
echo_blue "Ajout de la clé du dépôt..."
pct exec $CT_NEXT_ID -- bash -c "wget https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg -O /usr/share/keyrings/proxmox-archive-keyring.gpg"

# Installer Proxmox Backup Server dans le conteneur
echo_blue "Installation de Proxmox Backup Server..."
pct exec $CT_NEXT_ID -- bash -c "apt update && apt full-upgrade -y && apt install -y proxmox-backup-server"

# Récupérer l'adresse IP du conteneur
CT_IP=$(pct exec $CT_NEXT_ID -- hostname -I | awk '{print $1}')

echo_blue "=== Conteneur créé avec succès ==="
echo_blue "ID : $CT_NEXT_ID"
echo_blue "Nom : $HOSTNAME"
echo_blue "Pour accéder : pct enter $CT_NEXT_ID"
echo_blue "Pour arrêter : pct stop $CT_NEXT_ID"
echo_blue "Pour démarrer : pct start $CT_NEXT_ID"
echo_blue "Accéder à Nextcloud AIO via : https://$CT_IP:8007"

# Attacher un point de montage pour les sauvegardes
# Dans mon cas, sur mon host PVE, j'ai créer un directory (cf. menu disks) pbs-backups
pct stop $CT_NEXT_ID
echo_blue "Configuration du stockage des sauvegardes..."
pct set $CT_NEXT_ID -mp1 /mnt/pve/pbs-backups,mp=/pbs-backups
pct start $CT_NEXT_ID
echo_blue "Dans PBS, ajouter le datastore avec /pbs-backups/dump et penser à activer l'option Verify New Snapshots"
echo_blue "Dans PBS, créer un utilisateur proxmox puis, dans Permissions, lui ajouter le rôle DatastoreAdmin sur /datastore"
echo_blue "Dans PVE, ajouter le stockage de type Proxmox Backup Server pointant sur https://$CT_IP:8007"
echo_blue "Dans PVE, créer le job de sauvegarde en choisissant le stockage PBS"