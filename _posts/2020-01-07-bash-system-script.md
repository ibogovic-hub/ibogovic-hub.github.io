---
title: system script
tags: bash
article_header:
  type: cover
  image:
    src: /assets/images/wall/30681.jpg
---
>>>>
## **script that I created for system update and some installation**
>>>  

```bash
#!/bin/bash

#####################################################################################

TITLE="SysInfo Report for $HOSTNAME"
CURRENT_TIME=$(date +"%x %r %Z")
TIME_STAMP="Generated $CURRENT_TIME by $USER"

#####################################################################################
####-Update and clean of the system
UPDATE () {
	clear
	sudo apt -y update
	sudo apt -y full-upgrade
	sudo apt -y upgrade
	sudo apt -y dist-upgrade
	sudo apt -f install
	sudo apt -y autoremove
	sudo apt -y autoclean
	sudo apt -y clean
	echo
	echo
	echo
	echo
	echo "---------------->>>>>   Update finished   <<<<<-----------------"
	echo
	echo
	echo
	echo
}

#####################################################################################


#####################################################################################
####-App installation - edit per requirements
APP_INSTALLATION () {
sudo apt -y install \
	gcc vim dkms unace unrar zip unzip p7zip-full p7zip-rar bzip2 \
	mpack arj samba xchm wget network-manager-vpnc network-manager-vpnc-gnome vpnc mencoder \
	transmission libreoffice nmap openconnect network-manager-openconnect \
	network-manager-openconnect-gnome qemu-kvm virt-manager virtinst bridge-utils screen ssh \
	simplescreenrecorder cryptsetup wireless-tools ufw gufw libavcodec-extra ffmpeg \
	dnsutils keepassxc apt-transport-https ca-certificates synaptic gnome-tweak-tool ubuntu-restricted-extras \
	nautilus-dropbox gns3-gui gns3-server gns3-iou cups printer-driver-cups-pdf \
	bleachbit libdrm-amdgpu1 xserver-xorg-video-amdgpu flameshot vlan cherrytree \
	net-tools expect alacarte aptitude tre tree
	sudo snap install whatsdesk
	cd /tmp
	wget http://security.ubuntu.com/ubuntu/pool/main/o/openssl1.0/libssl1.0.0_1.0.2n-1ubuntu6.2_amd64.deb && sudo dpkg -i libssl1.0.0_1.0.2n-1ubuntu6.2_amd64.deb
	wget https://download.cdn.viber.com/cdn/desktop/Linux/viber.deb
	wget https://download.teamviewer.com/download/linux/teamviewer_amd64.deb
	wget https://go.skype.com/skypeforlinux-64.deb
	sudo wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/local/bin/youtube-dl
	sudo chmod a+x /usr/local/bin/youtube-dl
	sudo chmod +x *.deb
	sudo dpkg -i *.deb
	sudo apt install -y -f
	sudo rm *.deb
	sudo ufw default deny
	sudo ufw enable
	sudo ufw status verbose
	sudo rm -rf /tmp/*
}

#####################################################################################


#####################################################################################
####-Remove all not needed system folders
DELETE_FOLDERS () {
    sudo rm -rf ~/Documents
    sudo rm -rf ~/Public
    sudo rm -rf ~/Templates
    sudo rm -rf ~/Videos
    sudo rm -rf ~/Music
    sudo rm -rf ~/Pictures
}

#####################################################################################


#####################################################################################
####-Backup and add new repository links
SOURCES () {
	sudo dpkg --add-architecture i386
	sudo apt install dirmngr
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A2E3EF7B
	sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
	sudo rm /etc/apt/sources.list
	sudo echo "
# gns3
deb http://ppa.launchpad.net/gns3/ppa/ubuntu eoan main
deb-src http://ppa.launchpad.net/gns3/ppa/ubuntu eoan main

# cherrytree
deb http://ppa.launchpad.net/giuspen/ppa/ubuntu eoan main
deb-src http://ppa.launchpad.net/giuspen/ppa/ubuntu eoan main

" > sources.list
	sudo mv sources.list /etc/apt/sources.list
}

#####################################################################################

#####################################################################################
####-First install
PRVO () {
	sudo dpkg --add-architecture i386
	sudo apt update && sudo apt upgrade
	sudo apt install -y apt-transport-https ca-certificates libc6:i386 libstdc++6:i386 \
	sudo vim gcc dkms aptitude
}

#####################################################################################

#####################################################################################
###-reboot
REBOOT () {
	sudo reboot now 
}
#####################################################################################

#####################################################################################
###-reboot
SHUTDOWN () {
	sudo shutdown now
}
#####################################################################################

#####################################################################################
####-Menu section where to put all functions in the script
MENU () {
clear
echo
echo -e "\t\t\tChoose your lucky number\n"
echo -e "\t=================================================="
echo -e "\t          Test script to learn                    "
echo -e "\t          Created by: Ivan Bogovic                "
echo -e "\t          mail: bogovic@protonmail.com          "
echo -e "\t          Menu will change over time...           "
echo -e "\t==================================================\n\n\n"
echo -e "\ti. initial install"
echo -e "\t1. System Update & Clean"
echo -e "\t2. Backup & Add new repository"
echo -e "\t3. Application installation"
echo -e "\t4. Delete Folders (be sure that you want this!!!)"
echo -e "\t5. Reboot device"
echo -e "\t6. Shutdown device"
echo -e "\t0. Exit menu\n\n"
echo -en "\t\tEnter option: "
read -n 1 option
}

#####################################################################################


#####################################################################################
####-After MENU edit add it to file loop
while [[ 1 ]]; do
	MENU
		case $option in
		0)
			break ;;
		1)
			UPDATE ;;
		2)
			SOURCES ;;
		3)
			APP_INSTALLATION ;;
		4)
			DELETE_FOLDERS ;;
		5)
			REBOOT ;;
		6)
			SHUTDOWN ;;
		i)
			PRVO ;;
        *)
		clear
		echo "Sorry, wrong selection" ;;
	esac
	echo -en "\n\n\t\t\tHit any key to continue"
	read -n 1 line
done
clear
```