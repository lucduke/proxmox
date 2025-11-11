# Upgrade vers la version 7 de Proxmox Virtual Environment

## Les principales nouveautés

- Introduction de Debian 11 "Bullseye" et du kernel Linux 5.11
- Quick EMUlator 6.0
- LXC 4.0
- OpenZFS 2.0.4
- La gestion des dépôts à travers un IHM dédié
- La gestion du téléchargement des ISO à travers un IHM dédié
- ...

La release note est disponible ici : https://pve.proxmox.com/wiki/Roadmap#Proxmox_VE_7.0

## Tutoriel vidéo

[lien](https://youtu.be/cfUCejR8ads)

## L'upgrade de la 6.x vers la 7

Le détail des commandes à exécuter est décrit ici : https://pve.proxmox.com/wiki/Upgrade_from_6.x_to_7.0

Ci-après un résumé

```bash
# Mettre à jour sa configuration
apt update && apt dist-upgrade

# Arreter ses VM

# Valider la compatibilité de sa configuration
pve6to7 --full

# Mettre à jour ses dépôt Debian de buster vers bullseyes
cp /etc/apt/sources.list /etc/apt/sources-$(date +%s).bak
sed -i 's/buster\/updates/bullseye-security/g;s/buster/bullseye/g' /etc/apt/sources.list

cp /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise-$(date +%s).bak
echo "deb https://enterprise.proxmox.com/debian/pve bullseye pve-enterprise" > /etc/apt/sources.list.d/pve-enterprise.list

apt update

# Executer l'upgrade
apt dist-upgrade
```

## Redemarrer l'hôte

```shell
reboot
```

## Création d'un mdp d'application dans GMAIL

Pour les utilisateurs de GMAIL, il est nécessaire de créer un mot de passe d'application pour permettre à Proxmox d'envoyer des emails via le SMTP de GMAIL [lien.](https://support.google.com/accounts/answer/185833?hl=fr)
