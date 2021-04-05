#!/bin/bash

# The Duke Of Puteaux
# Rejoins moi sur Youtube: https://www.youtube.com/channel/UCsJ-FHnCEvtV4m3-nTdR5QQ

# USAGE
# wget -q -O - https://raw.githubusercontent.com/lucduke/proxmox/main/bash-custom.sh | bash

# SOURCES
# https://doc.ubuntu-fr.org/ls_couleur

# VARIABLES
timestamp=$(date +%s)

echo "----------------------------------------------------------------"
echo "Debut du script"
echo "----------------------------------------------------------------"

#1 Personnaliser la commande ls
echo "- Sauvegarder la configuration bash de l'utilisateur courant"
cd ~
cp .bashrc bashrc-$timestamp.bak

echo "- Personnaliser la commande ls"
if grep -Fq "# export LS_OPTIONS" .bashrc
  then
    echo "- LS option color commentée"
    sed -i.bak 's/# export LS_OPTION/export LS_OPTION/' .bashrc
  else
    echo "- LS option color déja non commentée"
fi

# You may uncomment the following lines if you want `ls' to be colorized:
# export LS_OPTIONS='--color=auto'
# eval "`dircolors`"
# alias ls='ls $LS_OPTIONS'


echo "----------------------------------------------------------------"
echo "Fin du script"
echo "----------------------------------------------------------------"

