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
cp .bashrc .bashrc-$timestamp.bak

echo "- Personnaliser la commande ls 1/3"
if grep -Fq "# export LS_OPTIONS" .bashrc
  then
    echo "- LS option color commentée 1/3"
    sed -i.bak "s/# export LS_OPTION/export LS_OPTION/" .bashrc
  else
    echo "- LS option color déja non commentée 1/3"
fi

echo "- Personnaliser la commande ls 2/3"
if grep -Fq "# eval \"\`dircolors\`\"" .bashrc
  then
    echo "- LS option color commentée 2/3"
    sed -i.bak "s/# eval \"\`dircolors\`\"/eval \"\`dircolors\`\"/" .bashrc
  else
    echo "- LS option color déja non commentée 2/3"
fi

echo "- Personnaliser la commande ls 3/3"
if grep -Fq "# alias ls=" .bashrc
  then
    echo "- LS option color commentée 3/3"
    sed -i.bak "s/# alias ls=/alias ls=/" .bashrc
  else
    echo "- LS option color déja non commentée 3/3"
fi

echo "----------------------------------------------------------------"
echo "Fin du script"
echo "----------------------------------------------------------------"

