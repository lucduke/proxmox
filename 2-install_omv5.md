# Installation d'OMV5 sur Proxmox



## Téléchargement ISO

````bash
cd /var/lib/vz/template/iso
wget -O openmediavault_5.5.11-amd64.iso https://sourceforge.net/projects/openmediavault/files/5.5.11/openmediavault_5.5.11-amd64.iso/download
````



## Création d'une VM

cf. vidéo



## MAJ système OMV

```bash
apt update && apt full-upgrade -y
```



## Installation qemu-agent

```bash
apt install -y qemu-guest-agent
reboot
```



## Installation des OMV-extra

```bash
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | bash
```

