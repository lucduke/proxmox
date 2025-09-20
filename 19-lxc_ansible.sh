#!/bin/bash

# Script pour créer un conteneur LXC sous Proxmox et installer Ansible
# Configuration :
# - Template : debian-13
# - Nom : ct-deb13-ansible
# - Disque : 6G
# - CPU : 1
# - RAM : 512M
# - Réseau : DHCP sur vmbr0
# - Ansible : installé via apt

set -e  # Arrêter en cas d'erreur

# Variables configurables
HOSTNAME="ct-deb13-ansible"              # Nom d'hôte
PASSWORD="motdepasse"                    # Mot de passe root
STORAGE="local-lvm"                      # Stockage Proxmox
STORAGE_TEMPLATE="nfs1-no-raid"          # Stockage pour les templates. Defaut = local
CORES="1"                                # Nombre de cœurs CPU
MEMORY="512"                             # Mémoire en MB
SWAP="512"                               # Swap en MB
DISK_SIZE="6"                            # Taille du disque en Go
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
        --ssh-public-keys /root/id_ed25519.pub \
        --unprivileged 1 \
        --features nesting=1 \
        --onboot 1 \
        --start 0
}


echo "=== Création du conteneur LXC pour Ansible ==="

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

# Installer Ansible
echo "Installation d'Ansible..."
pct exec $CT_NEXT_ID -- bash -c "apt update && apt full-upgrade -y && locale-gen fr_FR.UTF-8 && dpkg-reconfigure locales && update-locale"
pct exec $CT_NEXT_ID -- bash -c "echo 'LANGUAGE=fr_FR.UTF-8' >> /etc/default/locale"
pct exec $CT_NEXT_ID -- bash -c "echo 'LC_ALL=fr_FR.UTF-8' >> /etc/default/locale"
pct exec $CT_NEXT_ID -- bash -c "export DEBIAN_FRONTEND=noninteractive && ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime && dpkg-reconfigure --frontend noninteractive tzdata"
pct exec $CT_NEXT_ID -- bash -c "apt install -y ansible"

# Vérifier l'installation
echo "Vérification de l'installation d'Ansible..."
pct exec $CT_NEXT_ID -- bash -c "export LANG=fr_FR.UTF-8 && ansible --version"

echo "=== Conteneur créé avec succès ==="
echo "ID : $CT_NEXT_ID"
echo "Nom : ct-deb13-ansible"
echo "Pour accéder : pct enter $CT_NEXT_ID"
echo "Pour arrêter : pct stop $CT_NEXT_ID"