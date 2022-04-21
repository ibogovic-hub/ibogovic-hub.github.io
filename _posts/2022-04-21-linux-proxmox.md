---
title: usefull linux commands
tags: Linux
---

___
# Proxmox

## enable IOMMU
/etc/default/grub
￼
￼

### virtio ISO
[source](https://github.com/virtio-win)

#### Commands for single drive storage:
```sh
lvremove /dev/pve/data
lvresize -l +100%FREE /dev/pve/root
resize2fs /dev/mapper/pve-root
```
#### Commands to update ubuntu server
```sh
sudo apt update -y
sudo apt upgrade -y
```
#### Commands to install GNS3 server

[source](https://docs.gns3.com/docs/getting-started/installation/)
```sh
cd /tmp
curl curl https://raw.githubusercontent.com/GNS3/gns3-server/master/scripts/remote-install.sh > gns3-remote-install.sh
sudo bash remote-install.sh --with-iou --with-i386-repository
```

[generate ioukey](https://www.ipvanquish.com/2016/09/25/how-to-generate-cisco-iou-licence-on-gns3-vm-with-python-3/)

UUID="xxxxx" cifs iocharset=utf8,noperm 0 0

CONNECT Proxmox SHARE
- Ubuntu server download
[link](https://ubuntu.com/download/server)

- GNS3 remote server official documentation
[link](https://docs.gns3.com/docs/getting-started/installation/remote-server/)

- GNS3 desktop client download
[link](https://www.gns3.com/software/download)

### samba config
```sh
[share]
comment = Share
path = /share
writeable = yes
guest ok = yes
read only = no
browseable = yes
public = yes
create mask = 0777
directory mask = 0777
force user = root


hosts allow = 127.0.0.1 10.0.0.0/255.0.0.0 171.16.0.0/255.255.0.0 192.168.0.0/255.255.0.0
```

### network config
- separate interface for VM's
```sh
auto lo
iface lo inet loopback

iface enp34s0 inet manual

auto vmbr0
iface vmbr0 inet static
	address 192.168.1.253/24
	gateway 192.168.1.1
	bridge-ports enp34s0
	bridge-stp off
	bridge-fd 0

	post-up echo 1 > /proc/sys/net/ipv4/ip_forward
	post-up echo 1 > /proc/sys/net/ipv4/conf/enp34s0/proxy_arp

auto vmbr1
iface vmbr1 inet static
	address 10.10.10.1/24
	bridge-ports none
	bridge-stp off
	bridge-fd 0

	post-up		echo 1 > /proc/sys/net/ipv4/ip_forward
	post-up		iptables -t nat -A POSTROUTING -s '10.10.10.0/24' -o vmbr0 -j MASQUERADE
	post-down	iptables -t nat -D POSTROUTING -s '10.10.10.0/24' -o vmbr0 -j MASQUERADE

	post-up   iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
	post-down iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1
```