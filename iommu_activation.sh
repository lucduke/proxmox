#!/bin/bash

# The Duke Of Puteaux
# Rejoins moi sur Youtube: https://www.youtube.com/channel/UCsJ-FHnCEvtV4m3-nTdR5QQ

# USAGE
# wget -q -O - https://raw.githubusercontent.com/lucduke/proxmox/main/iommu_activation.sh | bash

# SOURCES
# https://forum.proxmox.com/threads/guide-intel-intergrated-graphic-passthrough.30451/

# VARIABLES
timestamp=$(date +%s)

echo "----------------------------------------------------------------"
echo "Debut du script"
echo "----------------------------------------------------------------"

# Modification GRUB

echo "Sauvegarde GRUB et ajout intel_iommu=on iommu=pt i915.enable_gvt=1"
sed -i.${timestamp}.bak 's/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet intel_iommu=on iommu=pt i915.enable_gvt=1\"/' /etc/default/grub

echo "lancement commande update-grub"
update-grub



# Modification /etc/modules

if [ -e /etc/modules ]
  then

    echo "Sauvegarde /etc/modules"
    cp /etc/modules /etc/modules.${timestamp}.bak

    if grep -Fq "vfio" /etc/modules
      then
        echo "Module vfio deja présent"
      else
        echo "Ajout module vfio"
        echo "vfio" >> /etc/modules
    fi

    if grep -Fq "vfio_iommu_type1" /etc/modules
      then
        echo "Module vfio_iommu_type1 deja présent"
      else
        echo "Ajout module vfio_iommu_type1"
        echo "vfio_iommu_type1" >> /etc/modules
    fi

    if grep -Fq "vfio_pci" /etc/modules
      then
        echo "Module vfio_pci"
      else
        echo "Ajout module vfio_pci"
        echo "vfio_pci" >> /etc/modules
    fi

    if grep -Fq "vfio_virqfd" /etc/modules
      then
        echo "Module vfio_virqfd deja présent"
      else
        echo "Ajout module vfio_virqfd"
        echo "vfio_virqfd" >> /etc/modules
    fi

  else
    echo "Creation /etc/modules"
    echo "vfio" >> /etc/modules
    echo "vfio_iommu_type1" >> /etc/modules
    echo "vfio_pci" >> /etc/modules
    echo "vfio_virqfd" >> /etc/modules
fi

echo "Lancement commande update-initramfs -u -k all"
update-initramfs -u -k all

echo "Redemmarage host"
reboot
