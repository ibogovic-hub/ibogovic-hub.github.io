---
title: kvm & whonix
tags: Linux
---

### create vm
virsh -c qemu:///system net-define Whonix_external*.xml

```html
<network>
  <name>External</name>
  <forward mode='nat'/>
  <bridge name='virbr2' stp='on' delay='0'/>
  <ip address='10.200.200.1' netmask='255.255.255.0'/>
</network>
```

```sh
virsh -c qemu:///system net-autostart External
virsh -c qemu:///system net-start External

virsh -c qemu:///system define Whonix-Gateway*.xml
```

```html
<ip address='10.152.152.0' netmask='255.255.192.0'>
    <dhcp>
      <range start='10.152.128.1' end='10.152.191.254'/>
    </dhcp>
</ip>
```

### sound KVM

```sh
sudo vim /etc/libvirt/qemu.conf
vnc_allow_host_audio = 1
user=root
group=root
sudo adduser `id -un` wireshark && sudo adduser `id -un` kvm && sudo adduser `id -un` libvirt && sudo adduser `id -un` libvirt-qemu && sudo adduser `id -un` libvirt-dnsmasq
apt install spice-vdagent - install kvm guest additions
```

- How to install whonix-gw-network-conf using apt-get

1. Download Whonix's Signing Key.

```sh
wget https://www.whonix.org/patrick.asc
```

2. Add Whonix's signing key.

```sh
sudo apt-key --keyring /etc/apt/trusted.gpg.d/whonix.gpg add ~/patrick.asc
```

3. Add Whonix's APT repository.

```sh
echo "deb https://deb.whonix.org buster main contrib non-free" | sudo tee /etc/apt/sources.list.d/whonix.list
```

4. Update your package lists.

```sh
sudo apt-get update
```

5. Install whonix-gw-network-conf.

```sh
sudo apt-get install whonix-gw-network-conf
```
