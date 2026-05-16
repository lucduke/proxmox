# Installation de Nextcloud AIO avec Docker Compose

## Prérequis

- Serveur Debian/Ubuntu avec accès root
- Ports 80, 8080, 8443 ouverts et accessibles depuis internet
- Un nom de domaine pointant vers le serveur (ex: `nextcloud.domain.eu`)
- Minimum 4 Go RAM, 20 Go d'espace disque

## 1. Installer Docker Engine et Compose

```bash
apt update
apt install -y docker.io docker-compose
systemctl enable --now docker
```

Vérifier l'installation :

```bash
docker version
docker compose version
```

## 2. Créer les volumes Docker

Nextcloud AIO nécessite plusieurs volumes persistants :

```bash
docker volume create nextcloud_aio_mastercontainer
docker volume create nextcloud_aio_nextcloud
docker volume create nextcloud_aio_nextcloud_data
docker volume create nextcloud_aio_database
docker volume create nextcloud_aio_database_dump
docker volume create nextcloud_aio_apache
docker volume create nextcloud_aio_redis
```

## 3. Créer le fichier docker-compose.yml

```bash
mkdir -p /opt/nextcloud-aio
```

Créer `/opt/nextcloud-aio/docker-compose.yml` :

```yaml
services:
  nextcloud-aio-mastercontainer:
    image: ghcr.io/nextcloud-releases/all-in-one:latest
    container_name: nextcloud-aio-mastercontainer
    restart: always
    ports:
      - "80:80"
      - "8080:8080"
      - "8443:8443"
    environment:
      - APACHE_PORT=11000
      - APACHE_IP_BINDING=0.0.0.0
    volumes:
      - nextcloud_aio_mastercontainer:/mnt/docker-aio-config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    init: true

volumes:
  nextcloud_aio_mastercontainer:
    external: true
  nextcloud_aio_nextcloud:
    external: true
  nextcloud_aio_nextcloud_data:
    external: true
  nextcloud_aio_database:
    external: true
  nextcloud_aio_database_dump:
    external: true
  nextcloud_aio_apache:
    external: true
  nextcloud_aio_redis:
    external: true
```

## 4. Démarrer Nextcloud AIO

```bash
cd /opt/nextcloud-aio
docker compose up -d
```

Le mastercontainer va automatiquement créer et gérer les sous-conteneurs :

| Conteneur | Rôle |
|---|---|
| `nextcloud-aio-mastercontainer` | Interface de gestion AIO |
| `nextcloud-aio-apache` | Reverse proxy Apache |
| `nextcloud-aio-nextcloud` | Application Nextcloud |
| `nextcloud-aio-database` | PostgreSQL |
| `nextcloud-aio-redis` | Cache Redis |
| `nextcloud-aio-imaginary` | Traitement d'images |
| `nextcloud-aio-notify-push` | Notifications push |

## 5. Configuration initiale

### 5.1 Accéder à l'interface AIO

Ouvrir `https://<ip-du-serveur>:8080`

Le mot de passe AIO se trouve dans les logs du mastercontainer :

```bash
docker logs nextcloud-aio-mastercontainer 2>&1 | grep -i password
```

Ou dans le fichier de configuration :

```bash
docker exec nextcloud-aio-mastercontainer cat /mnt/docker-aio-config/data/configuration.json
```

### 5.2 Configurer le domaine

Dans l'interface AIO (port 8080) :

1. Entrer le domaine (ex: `nextcloud.domain.eu`)
2. Configurer les options souhaitées (Collabora, OnlyOffice, Talk, etc.)
3. Cliquer sur **Save** puis **Start containers**

### 5.3 Obtenir un certificat SSL

Si les ports 80 et 8443 sont ouverts et que le domaine pointe vers le serveur :

1. Ouvrir `https://nextcloud.domain.eu:8443`
2. Le certificat Let's Encrypt est obtenu automatiquement

## 6. Vérifier le bon fonctionnement

```bash
# Vérifier que tous les conteneurs sont healthy
docker ps --format "table {{.Names}}\t{{.Status}}"

# Vérifier l'accès Nextcloud
curl -sk https://nextcloud.domain.eu/status.php

# Consulter les logs
docker logs -f nextcloud-aio-mastercontainer
```

## 7. Gérer les mises à jour

### 7.1 Mise à jour du mastercontainer

```bash
cd /opt/nextcloud-aio

# Pull de la nouvelle image
docker compose pull

# Redémarrer le mastercontainer
docker compose up -d
```

Le mastercontainer détectera les nouvelles versions des sous-conteneurs et les mettra à jour automatiquement.

### 7.2 Mise à jour de Nextcloud (application)

Nextcloud AIO gère les mises à jour de Nextcloud automatiquement via l'interface AIO :

1. Ouvrir `https://nextcloud.domain.eu:8080`
2. Section **Nextcloud version** : cliquer sur **Update** si disponible
3. Ou activer les mises à jour automatiques dans les paramètres AIO

### 7.3 Vérifier les mises à jour disponibles

```bash
# Vérifier si une nouvelle image mastercontainer est disponible
docker compose pull --quiet 2>&1

# Voir les images locales vs registry
docker images ghcr.io/nextcloud-releases/all-in-one
```

### 7.4 Procédure complète de mise à jour

```bash
cd /opt/nextcloud-aio

# 1. Backup des volumes (recommandé)
docker run --rm \
  -v nextcloud_aio_nextcloud_data:/data \
  -v /tmp/nc-backup:/backup \
  alpine tar czf /backup/nextcloud_data_$(date +%Y%m%d).tar.gz -C /data .

# 2. Pull des nouvelles images
docker compose pull

# 3. Redémarrage
docker compose down
docker compose up -d

# 4. Vérification
docker ps --format "table {{.Names}}\t{{.Status}}"
curl -sk https://nextcloud.domain.eu/status.php
```

### 7.5 Automatisation avec Watchtower (optionnel)

```bash
docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --schedule "0 0 4 * * *" \
  nextcloud-aio-mastercontainer
```

Watchtower vérifiera quotidiennement à 4h00 les nouvelles images et les appliquera automatiquement.

## 8. Commandes utiles

```bash
# Arrêter Nextcloud AIO
cd /opt/nextcloud-aio && docker compose down

# Redémarrer
cd /opt/nextcloud-aio && docker compose up -d

# Voir les logs en temps réel
docker logs -f nextcloud-aio-mastercontainer

# Accéder au shell d'un conteneur
docker exec -it nextcloud-aio-nextcloud bash

# Lister les volumes et leur taille
docker volume ls
for vol in $(docker volume ls -q); do
  echo "$vol: $(du -sh $(docker volume inspect $vol --format '{{.Mountpoint}}') 2>/dev/null)"
done

# Nettoyer les images inutilisées
docker image prune -f
```

## 9. Structure des volumes

| Volume | Contenu | Taille typique |
|---|---|---|
| `nextcloud_aio_nextcloud_data` | Fichiers utilisateurs | Variable (principal) |
| `nextcloud_aio_nextcloud` | Code Nextcloud + apps | ~1-2 Go |
| `nextcloud_aio_database` | Données PostgreSQL | ~100-500 Mo |
| `nextcloud_aio_database_dump` | Backups base de données | ~10-50 Mo |
| `nextcloud_aio_mastercontainer` | Config AIO | ~100 Ko |
| `nextcloud_aio_apache` | Config Apache | ~16 Ko |
| `nextcloud_aio_redis` | Données Redis | ~50 Ko |
