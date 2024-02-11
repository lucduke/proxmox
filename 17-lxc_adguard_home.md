# Création d'un conteneur LXC pour Adguard Home

## Tutoriel vidéo

[Lien vers la vidéo](https://)

## Mise à jour des templates de conteneur téléchargeable

Se connecter en SSH sur son hote Proxmox

```bash
# Mise à jour des templates
pveam update
```

## Téléchargement du template

Utilisation du template debian-12-standard

## Création du conteneur LXC

Création du rootfs de 8Go

Configuration du conteneur avec 2 coeurs, 2Go de RAM

Au niveau du paramétrage Réseau, sélectionner `DHCP` pour IPv4

Après le 1er démarrage du conteneur, activer `Start at boot`

## Maj système sur le conteneur

On se connext en SSH sur le conteneur

```bash
# Maj système
apt update
apt full-upgrade -y

# Maj le fuseau horaire
dpkg-reconfigure tzdata

# Installation de curl
apt install curl -y
```

## Installation de AdGuard Home

Suivre les instructions disponibles [ici :](https://github.com/AdguardTeam/AdGuardHome)

```bash
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
```

Pour contrôler AdGuard Home

```bash
sudo /opt/AdGuardHome/AdGuardHome -s start|stop|restart|status|install|uninstall
```

## Se connecter à AdGuard Home

Dans son navigateur, entre l'URL <http://localIP:3000>

On effectue via l'IHM les dernières étapes de configuration dans la création de son utilisateur

## Exemple de Parametres DNS dans la configuration Serveurs DNS upstream

```text
https://dns10.quad9.net/dns-query
[/*.home/]192.168.1.1
```
