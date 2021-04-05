#!/bin/bash

# The Duke Of Puteaux
# Rejoins moi sur Youtube: https://www.youtube.com/channel/UCsJ-FHnCEvtV4m3-nTdR5QQ

# USAGE
# wget -q -O - https://raw.githubusercontent.com/lucduke/proxmox/main/pve-no-subscription.sh | bash

# SOURCES
# https://pve.proxmox.com/wiki/Package_Repositories#sysadmin_no_subscription_repo

# VARIABLES
proxmoxlib="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
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


#4: Remove Subscription:

echo "----------------------------------------------------------------"
echo "Fin du script"
echo "----------------------------------------------------------------"
