#!/bin/bash

# Script pour créer un conteneur LXC sous Proxmox, installer podman et configurer WireGuard
# Source : https://wg-easy.github.io/
# Configuration :
# - Template : debian-13
# - Nom : ct-deb-wg-easy
# - Disque : 8G
# - CPU : 1
# - RAM : 512M
# - Réseau : DHCP sur vmbr0
# - Podman : installé via apt
# - WireGuard : configuré via wg-easy dans un conteneur podman

set -e  # Arrêter en cas d'erreur

# Variables configurables
HOSTNAME="ct-deb-wg-easy"                # Nom d'hôte
PASSWORD="motdepasse"                    # Mot de passe root
STORAGE="local-lvm"                      # Stockage Proxmox
STORAGE_TEMPLATE="nfs1-no-raid"          # Stockage pour les templates. Defaut = local
CORES="1"                                # Nombre de cœurs CPU
MEMORY="512"                             # Mémoire en MB
SWAP="512"                               # Swap en MB
DISK_SIZE="8"                            # Taille du disque en Go
NET_BRIDGE="vmbr0"                       # Interface réseau
TEMPLATE_NAME=""                         # Modèle Debian 13

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
        --ssh-public-keys /root/.ssh/id_rsa.pub \
        --unprivileged 1 \
        --features nesting=1 \
        --onboot 1 \
        --start 0
}

echo "=== Création du conteneur LXC pour WireGuard ==="

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
pct exec $CT_NEXT_ID -- bash -c "apt update && apt full-upgrade -y && apt install -y podman"

# Installer wg-easy dans un conteneur Podman executé dans le conteneur LXC
echo "Configuration de wg-easy dans un conteneur Podman..."
# Création des répertoires pour les configurations
echo "Création des répertoires pour les configurations..."
pct exec $CT_NEXT_ID -- bash -c "mkdir -p /etc/containers/systemd/wg-easy"
pct exec $CT_NEXT_ID -- bash -c "mkdir -p /etc/containers/volumes/wg-easy"

# Créer le service systemd pour wg-easy
echo "Création du fichier service pour wg-easy..."
pct exec $CT_NEXT_ID -- bash -c "cat <<EOF > /etc/containers/systemd/wg-easy/wg-easy.container
[Container]
ContainerName=wg-easy
Image=ghcr.io/wg-easy/wg-easy:15
AutoUpdate=registry

Volume=/etc/containers/volumes/wg-easy:/etc/wireguard:Z
Network=wg-easy.network
PublishPort=51820:51820/udp
PublishPort=51821:51821/tcp

# this is used to allow access over HTTP
# remove this when using a reverse proxy
Environment=INSECURE=true

AddCapability=NET_ADMIN
AddCapability=SYS_MODULE
AddCapability=NET_RAW
Sysctl=net.ipv4.ip_forward=1
Sysctl=net.ipv4.conf.all.src_valid_mark=1
Sysctl=net.ipv6.conf.all.disable_ipv6=0
Sysctl=net.ipv6.conf.all.forwarding=1
Sysctl=net.ipv6.conf.default.forwarding=1

[Install]
# this is used to start the container on boot
WantedBy=default.target
EOF"

# Création du fichier /etc/containers/systemd/wg-easy/wg-easy.network avec le contenu suivant :
echo "Création du fichier réseau pour wg-easy..."
pct exec $CT_NEXT_ID -- bash -c "cat <<EOF > /etc/containers/systemd/wg-easy/wg-easy.network
[Network]
NetworkName=wg-easy
IPv6=true
EOF"

# Chargement des modules du noyau sur mon hôte Proxmox
echo "Chargement des modules WireGuard et nft_masq..."
modprobe wireguard && modprobe nft_masq

# Création du fichier /etc/modules-load.d/wg-easy.conf avec le contenu suivant :
echo "Création du fichier de chargement des modules au démarrage..."
cat <<EOF > /etc/modules-load.d/wg-easy.conf
wireguard
nft_masq
EOF

# Activer et démarrer le service wg-easy
echo "Activation et démarrage du service wg-easy..."
pct exec $CT_NEXT_ID -- bash -c "systemctl daemon-reload"
pct exec $CT_NEXT_ID -- bash -c "systemctl start wg-easy"

# Vérifier que le conteneur Podman fonctionne
echo "Vérification de l'installation de wg-easy..."
pct exec $CT_NEXT_ID -- bash -c "podman ps"

echo "=== Conteneur créé avec succès ==="
echo "ID : $CT_NEXT_ID"
echo "Nom : $HOSTNAME"
echo "Pour accéder : pct enter $CT_NEXT_ID"
echo "Pour arrêter : pct stop $CT_NEXT_ID"