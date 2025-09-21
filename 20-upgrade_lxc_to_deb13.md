# Mise à niveau d’un conteneur LXC de Debian 12 vers Debian 13

Ce guide explique comment effectuer l’upgrade d’un conteneur LXC sous Debian 12 (Bookworm) vers Debian 13 (Trixie) en toute sécurité.

## Prérequis

- Un conteneur LXC fonctionnel sous Debian 12
- Les droits root sur le conteneur
- Une sauvegarde récente des données importantes

## Étapes de la procédure

### 1. Modifier les sources APT

Remplacez toutes les occurrences de `bookworm` par `trixie` dans le fichier des sources :

```bash
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
```

Vérifiez également les fichiers dans `/etc/apt/sources.list.d/` si besoin.

### 2. Mettre à jour l’index des paquets

```bash
apt update
```

### 3. Lancer la mise à niveau complète

```bash
apt dist-upgrade
```

Répondez aux éventuelles questions concernant la configuration des paquets.

### 4. Nettoyer le système

Supprimez les dépendances inutiles et nettoyez le cache :

```bash
apt autoremove -y && apt autoclean
```

### 5. Vérifier la configuration SSH

Ouvrez le fichier de configuration SSH pour vérifier ou adapter les paramètres :

```bash
nano /etc/ssh/sshd_config
```

Assurez-vous que la connexion SSH fonctionne toujours après la mise à niveau.

### 6. Moderniser les sources (optionnel)

Si le paquet `apt-modernize-sources` est disponible, vous pouvez l’utiliser pour adapter automatiquement les sources :

```bash
apt modernize-sources
```

### 7. Redémarrer le conteneur

Pour appliquer tous les changements :

```bash
reboot
```

## Conseils et vérifications

- Vérifiez que tous les services critiques démarrent correctement après le reboot.

- Contrôlez la version de Debian avec :

```bash
  lsb_release -a
```

- Consultez les journaux système en cas de problème :

```bash
  journalctl -xe
```

## Conclusion

La mise à niveau d’un conteneur LXC Debian est une opération relativement simple, mais il est essentiel de procéder avec prudence et de toujours disposer d’une sauvegarde. Cette procédure vous permet de bénéficier des dernières fonctionnalités et correctifs de sécurité de Debian 13 Trixie.