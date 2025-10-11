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

# Fonction pour générer un hash Argon2 pour le token admin
generate_argon2_hash() {
    # Vérifier si argon2 est installé
    if ! command -v argon2 &> /dev/null; then
        apt install -y argon2
    fi
    ADMIN_TOKEN=$(echo -n "MySecretPassword" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)
}

echo "=== Création du conteneur LXC pour Vaultwarden ==="

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

# Créer un volume pour Vaultwarden
echo "Création du volume pour Vaultwarden..."
pct exec $CT_NEXT_ID -- bash -c "podman volume create vaultwarden-data"
echo "Le volume est géré dans /var/lib/containers/storage/volumes/vaultwarden-data/_data"

# Générer le token admin
generate_argon2_hash
echo "Token admin généré."

# Création du fichier podman-compose.yml pour Vaultwarden
echo "Configuration de Vaultwarden..."
pct exec $CT_NEXT_ID -- bash -c "mkdir -p /opt/podman/vaultwarden && cd /opt/podman/vaultwarden && cat > podman-compose.yml <<EOF
services:
  vaultwarden:
    image: docker.io/vaultwarden/server:latest
    container_name: vaultwarden
    environment:
      - SIGNUPS_ALLOWED=\${signupsAllowed}
      - ADMIN_TOKEN=\${adminToken}
    volumes:
      - vaultwarden-data:/data
    ports:
      - 80:80/tcp
    restart: unless-stopped
volumes:
  vaultwarden-data:
    external: true
EOF"
    
# Création du fichier .env pour Vaultwarden
pct exec $CT_NEXT_ID -- bash -c "cd /opt/podman/vaultwarden && cat > .env <<EOF
# Permettre ou non les inscriptions
signupsAllowed=true
# Token d'administration (à changer)
adminToken=${ADMIN_TOKEN}
EOF"

## Création d'un service systemd pour démarrer Podman au boot du conteneur
echo "Création du service systemd pour Podman..."
pct exec $CT_NEXT_ID -- bash -c "cat > /etc/systemd/system/podman-vaultwarden.service <<EOF
[Unit]
Description=Podman Compose Vaultwarden Service
Requires=podman.service network.target
After=network.target

[Service]
Restart=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/podman-compose -f /opt/podman/vaultwarden/podman-compose.yml up
ExecStop=/usr/bin/podman-compose -f /opt/podman/vaultwarden/podman-compose.yml down

[Install]
WantedBy=multi-user.target
EOF"
pct exec $CT_NEXT_ID -- bash -c "systemctl daemon-reload && systemctl enable podman-vaultwarden.service"

# Lancer Vaultwarden avec podman-compose
echo "Lancement de Vaultwarden..."
pct exec $CT_NEXT_ID -- bash -c "cd /opt/podman/vaultwarden && podman-compose up -d"

# Vérifier que le conteneur Podman fonctionne
echo "Vérification de l'installation de Vaultwarden..."
pct exec $CT_NEXT_ID -- bash -c "podman ps"

# Récupérer l'adresse IP du conteneur
CT_IP=$(pct exec $CT_NEXT_ID -- hostname -I | awk '{print $1}')

echo "=== Conteneur créé avec succès ==="
echo "ID : $CT_NEXT_ID"
echo "Nom : $HOSTNAME"
echo "Pour accéder : pct enter $CT_NEXT_ID"
echo "Pour arrêter : pct stop $CT_NEXT_ID"
echo "Pour se connecter à Vaultwarden, passez imperativement par votre reverse proxy : https://$CT_IP"