#!/bin/bash

# The Duke Of Puteaux
# Rejoins moi sur Youtube: https://www.youtube.com/channel/UCsJ-FHnCEvtV4m3-nTdR5QQ

# USAGE
# wget -q -O - https://github.com/lucduke/proxmox/edit/main/pve-no-subscription.sh | bash

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
    echo "- Masquage du dépôt"
    sed -i 's/^/#/' /etc/apt/sources.list.d/pbs-enterprise.list
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
    sed -i "\$adeb http://download.proxmox.com/debian/pve $distribution pve-no-subscription" /etc/apt/sources.list
fi

#3: MAJ
echo "- MAJ OS"
apt update -y
apt full-upgrade -y


#4: Remove Subscription:
#checking if file is already edited in order to not edit again
if grep -Ewqi "void" $proxmoxlib; then
echo "- Subscription Message already removed - Skipping"
else
if [ -d "$pve_log_folder" ]; then
echo "- Removing No Valid Subscription Message for PVE"
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" $proxmoxlib && systemctl restart pveproxy.service
else 
echo "- Removing No Valid Subscription Message for PBS"
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" $proxmoxlib && systemctl restart proxmox-backup-proxy.service
fi
fi
