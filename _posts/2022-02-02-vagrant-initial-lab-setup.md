---
title: vagrant and ansible
tags: vagrant
---

# vagrant
> I'm using mac m1 and some things like vmware currently work funny.  
> In multy vm setup I needed to run the first machine with **"vagrant up"** and then uncomment other two machines to avoid the problem being stuck on assigning address or key generation.

- and yes....I'm playing with this so.. ;-)

## ***"Vagrant"*** File

```ini
# -*- mode: ruby -*-
# vi: set ft=ruby :


Vagrant.configure("2") do |config|
  
  config.vm.box = "bytesguy/ubuntu-server-21.10-arm64"
  config.ssh.insert_key = false
  config.vm.provider "vmware_desktop" do |vb|
    vb.linked_clone = true
    vb.memory = "2048"
    vb.cpus = "2"
  end
  
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "provision.yml"
#   ansible.playbook = "playbook.yml" --> using this somethimes to provision trough vagrant
  end
  
  # App Server 1
  config.vm.define "app1" do |app|
    app.vm.hostname = "app1-server.test"
    app.vm.network "private_network", ip: "10.10.10.100"
  end

 # App Server 2
 config.vm.define "app2" do |app|
   app.vm.hostname = "app2-server.test"
   app.vm.network "private_network", ip: "10.10.10.101"
 end

 # web Server 1
 config.vm.define "web" do |web|
   web.vm.hostname = "web-server.test"
   web.vm.network "private_network", ip: "10.10.10.102"
 end
end
```

## ansible ***"inventory"*** file

```ini
# App Servers
[app]
10.10.10.100
10.10.10.101

# Web Server
[web]
10.10.10.102

# All Servers
[multi:children]
app
web

# access vars
[multi:vars]
ansible_ssh_user=vagrant
ansible_ssh_private_key_file=/Users/bogovic/.vagrant.d/insecure_private_key
```

## ansible ***"hosts"*** file

```ini
controller ansible_connection=local
 app1   ansible_host=10.10.10.100 ansible_ssh_private_key_file=/Users/bogovic/.vagrant.d/insecure_private_key
 app2   ansible_host=10.10.10.101 ansible_ssh_private_key_file=/Users/bogovic/.vagrant.d/insecure_private_key
 web    ansible_host=10.10.10.102 ansible_ssh_private_key_file=/Users/bogovic/.vagrant.d/insecure_private_key
 ```

## ansible ***"ansible.cfg"*** file
```ini
[defaults]
INVENTORY = inventory

host_key_checking = no
ansible_ssh_private_key_file=/Users/bogovic/.vagrant.d/insecure_private_key
```

## ansible ***"playbook.yml"*** file
```yml
---
- name: Install something
  hosts: all
  become: true

  pre_tasks:
    - name: Install Updates if needed
      apt: update_cache=true cache_valid_time=3600

  tasks:
    - name: install NTP
      apt: name=ntp state=present

    - name: restart NTP
      service: name=ntp state=started enabled=yes

    - name: update NTP time
      shell: "sudo service ntp stop && sudo ntpd -gq && sudo service ntp start"

    - name: install vim
      apt: name=vim state=present

    - name: install vlc
      apt: name=vlc state=present

    - name: install gcc
      apt: name=gcc state=present

    - name: install dkms
      apt: name=dkms state=present
```