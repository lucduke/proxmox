# Reduire la taille de son disque sur un conteneur LXC

## Tutoriel vidéo

[Lien vers la vidéo](https://xxx)

## Procédure

On commence par lister les containeurs sur son hôte proxmox
```bash
pct list
```

On arrête ensuite le conteneur sur lequel on souhaite intervenir (le 201 dans mon exemple)
```bash
pct stop 201
```

On sauvegarde le conteneur via l'interface de proxmox

On identifie le point de montage du stockage où est stocké l'image disque du conteneur (Datacenter\Stockage)

On vérifie le file system

```bash
e2fsck -fy /mnt/pve/nfs-raid/images/201/vm-201-disk-0.raw
```

On redimensionne le file system:
```bash
resize2fs /mnt/pve/nfs-raid/images/201/vm-201-disk-0.raw <new size>
```

On edite la configuration du conteneur
```bash
nano /etc/pve/lxc/201.conf
```
rootfs: nfs-raid:201/vm-201-disk-0.raw,size=25G >> rootfs: nfs-raid:201/vm-201-disk-0.raw,size=<new size>

On redemarre le conteneur
```bash
pct start 201
```

Pour vérifier la nouvelle taille du disque dans le conteneur
```bash
pct enter 201
df -hT
```