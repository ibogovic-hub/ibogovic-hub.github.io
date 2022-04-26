---
title: install script
tags: Linux
---

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
        unace unrar zip unzip p7zip-full p7zip-rar bzip2 mpack arj \
        xchm network-manager-vpnc network-manager-vpnc-gnome vpnc mencoder \
        transmission libreoffice nmap openconnect openvpn network-manager-openconnect \
        network-manager-openconnect-gnome qemu-kvm virt-manager virtinst bridge-utils screen ssh \
        cryptsetup wireless-tools ufw gufw libavcodec-extra ffmpeg simplescreenrecorder cherrytree \
        dnsutils keepassxc apt-transport-https ca-certificates synaptic gnome-tweak-tool \
# comment restricted-extras if using debian 
        ubuntu-restricted-extras gns3-gui gns3-server gns3-iou \
        nautilus-dropbox cups printer-driver-cups-pdf bleachbit libdrm-amdgpu1 \
        xserver-xorg-video-amdgpu flameshot vlan net-tools expect alacarte aptitude tree ipcalc \
	evolution evolution-ews evolution-indicator evolution-plugins-experimental evolution-plugin-spamassassin
# uncomment if you plan to use it
        sudo snap install whatsdesk
        cd /tmp
# viber - uncomment if you don't want it
        wget -O https://download.cdn.viber.com/cdn/desktop/Linux/viber.deb
# teamviewer - comment out if you don't want it        
        wget https://download.teamviewer.com/download/linux/teamviewer_amd64.deb
# telegram desktop comment out if you don't want it
        wget "https://telegram.org/dl/desktop/linux"
        tar -xf linux && cd Telegram && sudo cp * /usr/bin/ && cd ..
# uncomment for debian and you plan to use gns3
# wget http://ftp.de.debian.org/debian/pool/main/p/pygtksourceview/python-gtksourceview2_2.10.1-3_amd64.deb
# skype - comment out if you don't want it
        wget https://go.skype.com/skypeforlinux-64.deb
# youtube-dl - uncomment if you don't want it
        sudo wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/local/bin/youtube-dl
        sudo chmod a+x /usr/local/bin/youtube-dl
# signal desktop - comment out if you don't want it
        wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg
        cat signal-desktop-keyring.gpg | sudo tee -a /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null
        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' |\
          sudo tee -a /etc/apt/sources.list.d/signal-xenial.list
        sudo apt update && sudo apt install signal-desktop
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
####-First install
PRVO () {
        sudo dpkg --add-architecture i386
        sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A2E3EF7B
        sudo apt update && sudo apt upgrade
        sudo apt install -y apt-transport-https ca-certificates libc6:i386 libstdc++6:i386 
    	sudo add-apt-repository -y ppa:giuspen/ppa
    	sudo add-apt-repository -y ppa:gns3/ppa
    	sudo add-apt-repository -y ppa:phoerious/keepassxc
    	sudo add-apt-repository -y ppa:maarten-baert/simplescreenrecorder
        sudo apt -y install vim gcc dkms aptitude dirmngr wget
        sudo apt -y remove --purge aisleriot gnome-mahjongg gnome-sudoku aisleriot gnome-mahjongg gnome-sudoku
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
echo -e "\t          learning script                         "
echo -e "\t          Created by: Ivan Bogovic                "
echo -e "\t          mail: bogovic@protonmail.com            "
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
