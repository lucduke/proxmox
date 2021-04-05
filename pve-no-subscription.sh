#!/bin/bash

# The Duke Of Puteaux
# Rejoins moi sur Youtube: https://www.youtube.com/channel/UCsJ-FHnCEvtV4m3-nTdR5QQ

# USAGE
# wget -q -O - https://raw.githubusercontent.com/lucduke/proxmox/main/pve-no-subscription.sh | bash

# SOURCES
# https://pve.proxmox.com/wiki/Package_Repositories#sysadmin_no_subscription_repo

# VARIABLES
distribution=$(grep -F "VERSION_CODENAME=" /etc/os-release | cut -d= -f2)
timestamp=$(date +%s)

echo "----------------------------------------------------------------"
echo "Debut du script"
echo "----------------------------------------------------------------"

#1 Suppression / Ajouts de dépôts
# pve-enterprise.list
echo "- Sauvegarde pve-enterprise.list"
cp /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise-$timestamp.bak

echo "- Vérification pve-entreprise.list"
if grep -Fxq "#deb https://enterprise.proxmox.com/debian/pve $distribution pve-enterprise" /etc/apt/sources.list.d/pve-enterprise.list
  then
    echo "- Dépôt déja commenté"
  else
    echo "- Masquage du dépôt en ajoutant # à la première ligne"
    sed -i 's/^/#/' /etc/apt/sources.list.d/pve-enterprise.list
fi

# pve-no-subscription
echo "- Sauvegarde sources.list"
cp /etc/apt/sources.list /etc/apt/sources-$timestamp.bak

echo "- Vérification sources.list"
if grep -Fxq "deb http://download.proxmox.com/debian/pve $distribution pve-no-subscription" /etc/apt/sources.list
  then
    echo "- Dépôt déja présent"
  else
    echo "- Ajout du dépôt pve-no-subscription"
    echo "deb http://download.proxmox.com/debian/pve $distribution pve-no-subscription" >> /etc/apt/sources.list
fi

#3: MAJ
echo "- MAJ OS"
apt update -y
apt full-upgrade -y


#4: Supprimer le pop-up de souscription
echo "- Sauvegarde proxmoxlib.js"
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib-$timestamp.bak

echo "- Verificiation pop-up souscription"
if grep -Fx "void" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
  then
    echo "- Modification déja présente"
  else
    echo "- Application modification"
    sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    systemctl restart pveproxy.service
fi

#4: Optimisation SWAP
echo "- Paramatrage du SWAP pour qu'il ne s'active que lorsqu'il ne reste plus que 10% de RAM dispo"
sysctl vm.swappiness=10
echo "- Désactivation du SWAP"
swapoff -a
echo "- Activation du SWAP"
swapon -a

echo "----------------------------------------------------------------"
echo "Fin du script"
echo "----------------------------------------------------------------"
