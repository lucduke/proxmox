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
