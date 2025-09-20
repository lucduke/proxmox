#!/bin/bash

# Variables configurables
CT_ID="207"                              # ID du conteneur
HOSTNAME="ct-deb12-navi"                 # Nom d'hôte
PASSWORD="motdepasse"                    # Mot de passe root
STORAGE="local-lvm"                      # Stockage Proxmox
STORAGE_TEMPLATE="nfs1-no-raid"          # Stockage pour les templates. Defaut = local
CORES="2"                                # Nombre de cœurs CPU
MEMORY="512"                             # Mémoire en MB
SWAP="512"                               # Swap en MB
DISK_SIZE="5"                            # Taille du disque en Go
NET_BRIDGE="vmbr0"                       # Interface réseau
MP_MUSIC="/mnt/lxc/music"                # Point de montage de la musique
MUSIC_DIR="/media/music"                 # Répertoire de stockage de la musique
TEMPLATE=""                              # Modèle Debian 12
USER="navidrome"                         # Utilisateur Navidrome
GROUP="navidrome"                        # Groupe Navidrome
NAVRIOME_VERSION="0.54.4"                # Version de Navidrome

# Fonction pour vérifier le succès d'une commande
check_success() {
    if [ $? -ne 0 ]; then
        echo "Erreur lors de l'exécution de la commande précédente. Abandon."
        exit 1
    fi
}

# Fonction pour vérifier si l'utilisateur est root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Ce script doit être exécuté en tant que root."
        exit 1
    fi
}

# Fonction pour télécharger le dernier template Debian 12
download_latest_debian12_template() {
    # Mettre à jour la liste des templates disponibles
    echo "Mise à jour de la liste des templates..."
    pveam update

    # Rechercher le dernier template Debian 12 disponible
    echo "Recherche du dernier template Debian 12..."
    LATEST_TEMPLATE=$(pveam available --section system | grep -oP 'debian-12-standard_\K[0-9.-]+_amd64\.tar\.zst' | sort -V | tail -n 1)

    if [ -z "$LATEST_TEMPLATE" ]; then
        echo "Aucun template Debian 12 trouvé."
        exit 1
    fi

    # Construire le nom complet du template
    TEMPLATE="debian-12-standard_${LATEST_TEMPLATE}"

    echo "Dernier template Debian 12 trouvé : $TEMPLATE"

    # Télécharger le template
    echo "Téléchargement du template..."
    pveam download ${STORAGE_TEMPLATE} "$TEMPLATE"
    check_success
}

# Fonction pour créer le conteneur
create_container() {
    pct create $CT_ID \
        ${STORAGE_TEMPLATE}:vztmpl/$TEMPLATE \
        --ostype debian \
        --hostname $HOSTNAME \
        --password "$PASSWORD" \
        --cores $CORES \
        --memory $MEMORY \
        --swap $SWAP \
        --storage $STORAGE \
        --rootfs $STORAGE:$DISK_SIZE \
        --mp0 ${MP_MUSIC},mp=${MUSIC_DIR} \
        --net0 name=eth0,bridge=$NET_BRIDGE,ip=dhcp \
        --ssh-public-keys /root/id_ed25519.pub \
        --unprivileged 1 \
        --features nesting=1 \
        --onboot 1 \
        --start 1
    check_success
}

# Exécution des fonctions
check_root
download_latest_debian12_template
create_container

echo "Conteneur $CT_ID créé et démarré avec succès."

echo "Conteneur en cours de configuration..."
sleep 15

# Mise à jour et installation des dépendances
pct exec $CT_ID -- bash -c "apt update && apt upgrade -y"
check_success
pct exec $CT_ID -- bash -c "apt install -y nano ffmpeg wget"
check_success

# Installation de Navidrome
# Création de l'utilisateur et des répertoires
pct exec $CT_ID -- bash -c "adduser ${USER} --gecos '' --disabled-password"
check_success
pct exec $CT_ID -- bash -c "install -d -o ${USER} -g ${GROUP} /opt/navidrome"
check_success
pct exec $CT_ID -- bash -c "install -d -o ${USER} -g ${GROUP} /var/lib/navidrome"
check_success
pct exec $CT_ID -- bash -c "groupadd -g 10000 lxc_samba"
check_success
pct exec $CT_ID -- bash -c "usermod -aG lxc_samba ${USER}"
check_success

# Téléchargement de Navidrome
pct exec $CT_ID -- bash -c "wget https://github.com/navidrome/navidrome/releases/download/v${NAVRIOME_VERSION}/navidrome_${NAVRIOME_VERSION}_linux_amd64.tar.gz -O Navidrome.tar.gz"
check_success
pct exec $CT_ID -- bash -c "tar -xvzf Navidrome.tar.gz -C /opt/navidrome/"
check_success
pct exec $CT_ID -- bash -c "chmod +x /opt/navidrome/navidrome"
check_success
pct exec $CT_ID -- bash -c "chown -R ${USER}:${GROUP} /opt/navidrome"
check_success
# Configuration de Navidrome
pct exec $CT_ID -- bash -c "cat > /var/lib/navidrome/navidrome.toml <<EOF
MusicFolder = \"$MUSIC_DIR\"
Port = 4533
EnableTranscodingConfig = true
EnableDownloads = true
EnableSharing = true
DefaultLanguage = \"fr\"
ScanSchedule = \"@hourly\"
EOF"
check_success
# Création du service systemd
pct exec $CT_ID -- bash -c "cat > /etc/systemd/system/navidrome.service <<EOF
[Unit]
Description=Navidrome Music Server and Streamer compatible with Subsonic/Airsonic
After=remote-fs.target network.target
AssertPathExists=/var/lib/navidrome

[Install]
WantedBy=multi-user.target

[Service]
User=navidrome
Group=navidrome
Type=simple
ExecStart=/opt/navidrome/navidrome --configfile \"/var/lib/navidrome/navidrome.toml\"
WorkingDirectory=/var/lib/navidrome
TimeoutStopSec=20
KillMode=process
Restart=on-failure

# See https://www.freedesktop.org/software/systemd/man/systemd.exec.html
DevicePolicy=closed
NoNewPrivileges=yes
PrivateTmp=yes
PrivateUsers=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=yes
RestrictRealtime=yes
SystemCallFilter=~@clock @debug @module @mount @obsolete @reboot @setuid @swap
ReadWritePaths=/var/lib/navidrome

# You can uncomment the following line if you're not using the jukebox This
# will prevent navidrome from accessing any real (physical) devices
#PrivateDevices=yes

# You can change the following line to \`strict\` instead of \`full\` if you don't
# want navidrome to be able to write anything on your filesystem outside of
# /var/lib/navidrome.
ProtectSystem=full

# You can uncomment the following line if you don't have any media in /home/*.
# This will prevent navidrome from ever reading/writing anything there.
ProtectHome=true

# You can customize some Navidrome config options by setting environment variables here. Ex:
#Environment=ND_BASEURL="/navidrome"
EOF"
check_success
# Redémarrage du service
pct exec $CT_ID -- systemctl daemon-reload
check_success
pct exec $CT_ID -- systemctl start navidrome.service
check_success
pct exec $CT_ID -- systemctl status navidrome.service
check_success
pct exec $CT_ID -- systemctl enable navidrome.service
check_success

# Récupération de l'IP
IP=""
while [ -z "$IP" ]
do
    IP=$(pct exec $CT_ID -- bash -c "ip -4 addr show eth0 | grep inet | awk '{print \$2}' | cut -d/ -f1" 2>/dev/null)
    check_success
    sleep 2
done

echo ""
echo "Navidrome a été installé avec succès !"
echo "Accès :"
echo "Adresse IP du conteneur: $IP"
echo "Interface web: http://$IP:4533"
echo "Identifiants par défaut:"
echo "Utilisateur: admin"
echo "Mot de passe: admin"
echo ""
echo "Post-installation nécessaire :"
echo "1. Placer vos fichiers musicaux dans $MUSIC_DIR"
echo "2. Modifier le mot de passe admin dans l'interface web"
echo "3. Ajuster /var/lib/navidrome/navidrome.toml si nécessaire"