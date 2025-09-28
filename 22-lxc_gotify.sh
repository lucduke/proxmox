#!/usr/bin/env bash

# Script pour créer un conteneur LXC sous Proxmox, installer Gotify
# Source : https://github.com/gotify/server
# Configuration :
# - Template : debian-13
# - Nom : ct-deb-gotify
# - Disque : 2G
# - CPU : 1
# - RAM : 512M
# - Réseau : DHCP sur vmbr0
# - Gotify : installé via binaire dans /opt/gotify

# Variables
set -e  # Arrêter en cas d'erreur

# Variables configurables
HOSTNAME="ct-deb-gotify"                 # Nom d'hôte
PASSWORD="motdepasse"                    # Mot de passe root
STORAGE="local-lvm"                      # Stockage Proxmox
STORAGE_TEMPLATE="nfs1-no-raid"          # Stockage pour les templates. Defaut = local
CORES="1"                                # Nombre de cœurs CPU
MEMORY="512"                             # Mémoire en MB
SWAP="512"                               # Swap en MB
DISK_SIZE="2"                            # Taille du disque en Go
NET_BRIDGE="vmbr0"                       # Interface réseau
TEMPLATE_NAME=""                         # Modèle Debian 13
VERSION="2.7.3"                          # Version de Gotify
PLATFORM="linux-amd64"                   # Plateforme (linux-amd64, linux-arm64, etc.)

# Fonction pour vérifier si l'utilisateur est root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Ce script doit être exécuté en tant que root."
        exit 1
    fi
}

# Fonction pour télécharger le template si nécessaire
download_template_if_needed() {
    echo "Mise à jour de la liste des templates..."
    pveam update
    TEMPLATE_NAME=$(pveam available --section system | grep debian-13-standard | awk '{print $2}')
    if ! pveam list $STORAGE_TEMPLATE | grep -q "$TEMPLATE_NAME"; then
        echo "Téléchargement du template $TEMPLATE_NAME..."
        pveam download $STORAGE_TEMPLATE $TEMPLATE_NAME
    else
        echo "Template $TEMPLATE_NAME déjà disponible."
    fi
}

# Fonction pour créer le conteneur
create_container() {
    pct create $CT_NEXT_ID \
        ${STORAGE_TEMPLATE}:vztmpl/$TEMPLATE_NAME \
        --ostype debian \
        --hostname $HOSTNAME \
        --password "$PASSWORD" \
        --cores $CORES \
        --memory $MEMORY \
        --swap $SWAP \
        --storage $STORAGE \
        --rootfs $STORAGE:$DISK_SIZE \
        --net0 name=eth0,bridge=$NET_BRIDGE,ip=dhcp \
        --ssh-public-keys /root/.ssh/id_chris-i5.pub \
        --unprivileged 1 \
        --features nesting=1 \
        --onboot 1 \
        --start 0
}

echo "=== Création du conteneur LXC pour Gotify ==="

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

# Maj du conteneur et installation des dépendances
echo "Mise à jour du conteneur..."
pct exec $CT_NEXT_ID -- bash -c "apt update && apt full-upgrade -y && apt install -y unzip"

# Installer Gotify dans le conteneur
echo "Installation de Gotify..."
pct exec $CT_NEXT_ID -- bash -c "mkdir -p /opt/gotify && cd /tmp && \
wget https://github.com/gotify/server/releases/download/v${VERSION}/gotify-${PLATFORM}.zip && \
unzip gotify-${PLATFORM}.zip && \
chmod +x gotify-${PLATFORM} && \
mv gotify-${PLATFORM} /opt/gotify/gotify-${PLATFORM}"

# Ajouter Gotify au démarrage du conteneur en créant un service systemd
echo "Configuration du service systemd pour Gotify..."
pct exec $CT_NEXT_ID -- bash -c "cat <<EOF > /etc/systemd/system/gotify.service
[Unit]
Description=Gotify Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/gotify
ExecStart=/opt/gotify/gotify-${PLATFORM}
Restart=always

[Install]
WantedBy=multi-user.target
EOF"

pct exec $CT_NEXT_ID -- systemctl daemon-reload
pct exec $CT_NEXT_ID -- systemctl enable gotify.service
pct exec $CT_NEXT_ID -- systemctl start gotify.service


# Récupérer l'adresse IP du conteneur
CT_IP=$(pct exec $CT_NEXT_ID -- hostname -I | awk '{print $1}')

# Afficher les informations de connexion
echo "=== Conteneur créé avec succès ==="
echo "ID : $CT_NEXT_ID"
echo "Nom : $HOSTNAME"
echo "Pour accéder : pct enter $CT_NEXT_ID"
echo "Pour arrêter : pct stop $CT_NEXT_ID"
echo "Pour se connecter à Gotify : http://$CT_IP:80"
echo "Utilisateur par défaut : admin"
echo "Mot de passe par défaut : admin"  # À changer après la première connexion
echo "=================================="
