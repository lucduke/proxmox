# Reduire la taille de son disque sur un conteneur LXC

## Tutoriel vidéo

[Lien vers la vidéo](https://xxx)

## Procédure

On commence par lister les VM sur son hôte proxmox

```bash
qm list
```

On arrête ensuite la VM sur laquelle on souhaite intervenir (la 100 dans mon exemple)

```bash
qm stop 100
```

On sauvegarde la VM via l'interface de proxmox

On identifie le point de montage du stockage où est stocké l'image disque de la VM (Datacenter\Stockage)

On créé un fichier temporaire qcow2 sur lequel on souhaite travailler

```bash
cp /mnt/pve/nfs-raid/images/100/vm-100-disk-1.qcow2 /mnt/pve/nfs-raid/images/100/vm-100-disk-1.qcow2_tmp
```

On réduit la taille du disque qcow2 pour récupérer l'espace libre

```bash
qemu-img convert -O qcow2 /mnt/pve/nfs-raid/images/100/vm-100-disk-1.qcow2_tmp /mnt/pve/nfs-raid/images/100/vm-100-disk-1.qcow2
```

On redemarre la VM

```bash
qm start 100
```

Si OK, on supprime le fichier temporaire

```bash
/mnt/pve/nfs-raid/images/100/vm-100-disk-1.qcow2_tmp
```
