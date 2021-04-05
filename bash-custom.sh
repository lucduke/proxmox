#!/bin/bash

# The Duke Of Puteaux
# Rejoins moi sur Youtube: https://www.youtube.com/channel/UCsJ-FHnCEvtV4m3-nTdR5QQ

# USAGE
# wget -q -O - https://raw.githubusercontent.com/lucduke/proxmox/main/bash-custom.sh | bash

# SOURCES
# https://doc.ubuntu-fr.org/ls_couleur

# VARIABLES


echo "----------------------------------------------------------------"
echo "Debut du script"
echo "----------------------------------------------------------------"

#1 Personnaliser la commande ls
echo "- Sauvegarder la configuration bash de l'utilisateur courant"
cd ~
cp .bashrc bashrc-$timestamp.bak

echo "- Personnaliser la commande ls"
alias ls='ls --color' >> .bashrc

echo "----------------------------------------------------------------"
echo "Fin du script"
echo "----------------------------------------------------------------"

