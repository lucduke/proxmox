# Création d'une VM debian 12 à partir d'une image cloud

## Tutoriel vidéo

[Lien vers la vidéo](https://youtu.be/Xa2ASr9yZUQ)

## Etape 1 : téléchargement de l'image cloud sur le site de debian

Dans mon installation proxmox, je stocke les images ISO dans mon stockage nfs1-no-raid accessible via le chemin /mnt/pve/nfs1-no-raid
Une fois connecté en SSH sur mon serveur Proxmox

```bash
cd /mnt/pve/nfs1-no-raid/template/iso
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
```

## Etape 2 : Création d'une VM debian 12 que l'on transformera en template

On commence par créer la VM

```bash
qm create 1000 --name debian-12-cloud --memory 2048 --balloon 0 --cores 2 --cpu x86-64-v2-AES --net0 virtio,bridge=vmbr0 --onboot 0 --agent 1
```

On importe ensuite le disque au format qcow2 dans la VM. A noter que je stocke mes disques de VM dans le stockage nfs-raid et non local-lvm

```bash
qm importdisk 1000 debian-12-generic-amd64.qcow2 nfs-raid
```

On obtient le message suivant : `Successfully imported disk as 'unused0:nfs-raid:1000/vm-1000-disk-0.raw'`

Puis on l'attache en tant que disque SCSI à la VM

```bash
qm set 1000 --scsihw virtio-scsi-pci --scsi0 nfs-raid:1000/vm-1000-disk-0.raw
```

On définit ensuite un disque CD-ROM cloud-init pour cette VM

```bash
qm set 1000 --ide2 nfs-raid:cloudinit
```

On définit ensuite le disque scsi0 comme bootable

```bash
qm set 1000 --boot c --bootdisk scsi0
```

On créé un port série pour la VM

```bash
qm set 1000 --serial0 socket --vga serial0
```

Optionel : si vous souhaitez que la machine virtuelle soit avec un bios UEFI

```bash
qm set 1000 --bios ovmf --machine q35
qm set 1000 --efidisk0 nfs-raid:1,format=qcow2,efitype=4m,pre-enrolled-keys=1
```

## Etape 3 : Paramétrage de cloud-init

Via l'interface de proxmox, on configure l'utilisateur, le mot de passe, la clef publique SSH et la configuration IPv4 en DHCP

## Etape 4 : On convertit la VM en template

Via l'interface de proxmox, on sélectionne la VM et on la convertit en template que l'on pourra ensuite cloner à l'infini

## Etape 5 : Clonage de la VM

Une fois la VM clonée (en mode full) et démarrée, n'oubliez pas de reconfigurer la timezone et d'installer qemu-guest-agent

```bash
sudo dpkg-reconfigure tzdata
sudo apt install qemu-guest-agent
```
