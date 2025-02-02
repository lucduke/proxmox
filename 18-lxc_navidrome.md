# Installer Navidrome dans un conteneur LXC avec un script Bash

[Navidrome](https://www.navidrome.org/) est un serveur de streaming musical open-source, léger et auto-hébergé. Il permet d'accéder à sa bibliothèque musicale depuis n'importe quel appareil, via une interface web moderne ou des clients compatibles Subsonic/Airsonic.

## Fonctionnalités clés

- 🎶 Support des formats MP3, FLAC, OGG, OPUS, etc.
- 🔍 Recherche intelligente et organisation par métadonnées
- 📱 Applications mobiles compatibles (DSub, Symfonium, etc.)
- 🌍 Interface web réactive (Thèmes personnalisables)
- 🔒 Sécurité avec HTTPS et authentification

## Prérequis

- Accès root ou sudo à votre hôte Proxmox
- Un répertoire contenant votre bibliothèque musicale

## Étape 1 : Téléchargement du script d'installation sur votre hôte Proxmox

```bash
wget https://raw.githubusercontent.com/lucduke/proxmox/refs/heads/main/navidrome.sh
chmod +x navidrome.sh
```

##  Etape 2 : Création du conteneur LXC via un script Bash

Dans le script bash, personnalisez les variables définies en début de script ainsi que la clef ssh à utiliser pour la connexion au conteneur.

On execute ensuite le script bash pour créer le conteneur LXC et installer Navidrome.

```bash
bash navidrome.sh
```
