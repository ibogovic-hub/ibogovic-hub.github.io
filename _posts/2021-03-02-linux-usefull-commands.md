---
title: usefull linux commands
layout: article
tags: Linux
article_header:
 type: cover
---

---

## so...here is a bunch of linux commands that I have collected over the years

## I'm not quite sure how usefull is this here but...who knows. ;)

---

- for something

```sh
localectl set-keymap map
```

- in case you have the problem with pyhthon after installing gns3 

```sh
sudo ln -s /usr/bin/python3 /usr/bin/python
```

### DNS settings - check public IP with CLI

```sh
curl ifconfig.me
```

### Crypt folder with cli

```sh
7z a -p Fdirectory.7z /path/to/F
```

### Viber scaling workaround

```sh
sudo vim /usr/share/applications/viber.desktop
Exec=env QT_SCALE_FACTOR=0.6 /opt/viber/Viber
```

### PIDGIN

<https://sourceforge.net/p/sipe/wiki/Frequently%20Asked%20Questions/>
<https://linuxconfig.org/install-gnome-gui-on-rhel-7-linux-server>

### Youtube-dl

```sh
sudo wget <https://yt-dl.org/downloads/latest/youtube-dl> -O /usr/local/bin/youtube-dl
sudo chmod a+x /usr/local/bin/youtube-dl
youtube-dl -f bestvideo+bestaudio <https://youtu.be/KTji1hOICEI>
youtube-dl -f bestvideo+bestaudio -o '%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s' "https://www.youtube.com/watch?v=WJlfVjGt6Hg&list=PL1512BD72E7C9FFCA"
--playlist-start NUMBER     Playlist video to start at (default is 1)

--playlist-end NUMBER      Playlist video to end at (default is last)

--playlist-items ITEM_SPEC    Playlist video items to download. Specify
                 indices of the videos in the playlist
                 separated by commas like: "--playlist-items
                 1,2,5,8" if you want to download videos
                 indexed 1, 2, 5, 8 in the playlist. You can
                 specify range: "--playlist-items
                 1-3,7,10-13", it will download the videos
                 at index 1, 2, 3, 7, 10, 11, 12 and 13.
mp3 --playlist-items 1-7,9-12,14-79,81-87,89-91,93-98,100-110,112-120 "https://www.youtube.com/playlist?list=PLs_BtJUr-PzQQLWIg82WdIOyYs0An9jzi"

- Download YouTube playlist videos in separate directory indexed by video order in a playlist 

youtube-dl -o '%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s' <https://www.youtube.com/playlist?list=PLwiyx1dc3P2JR9N8gQaQN_BCvlSlap7re>

- Download all playlists of YouTube channel/user keeping each playlist in separate directory:

youtube-dl -o '%(uploader)s/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s' "https://www.youtube.com/user/TheLinuxFoundation/playlists"

youtube-dl -f bestaudio -o '%(uploader)s/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s' "https://www.youtube.com/c/GreenDay/playlists?view=71&sort=dd&shelf_id=3"
```

### simplescreenrecorder & GNS3 repo

```sh
sudo add-apt-repository ppa:maarten-baert/simplescreenrecorder
sudo add-apt-repository ppa:gns3/ppa
sudo add-apt-repository ppa:nm-l2tp/network-manager-l2tp
```

### OBS Studio

```sh
sudo apt-get install ffmpeg
sudo add-apt-repository ppa:obsproject/obs-studio
sudo apt-get update
sudo apt-get install obs-studio
```

### FortiClient

<https://hadler.me/linux/forticlient-sslvpn-deb-packages/>

### change default sudo permission

```sh
Visudo
# <user> ALL=(ALL:ALL) ALL
```

### channel scan

```sh
w_scan -c HR -X > channels.conf
# vlc channels.conf
```

### Making a bootable installation disk 

```sh
dd if=/path/to/<image_name> of=/dev/fd0 rawrite.exe
```

### ffmpeg conversion

```sh
ffmpeg -i input.wav -vn -ar 48000 -ac 2 -ab 320k -f mp3 output.mp3
for i in *.webm; do ffmpeg -i "$i" -vn -ar 48000 -ac 2 -ab 320k -f mp3 "${i%.*}.mp3"; done
ffmpeg -i *.mkv -vn -ar 48000 -ac 2 -ab 320k -f mp3 xxx.mp3
```

### rdesktop

```sh
rdesktop -u lc-adm -d localhost -g 1440x840 192.168.194.79
```

### dd

```sh
sudo dd if=/dev/urandom of=/dev/mmcblk0
```

### slow usb workaround

```sh
echo $((16*1024*1024)) > /proc/sys/vm/dirty_background_bytes
echo $((48*1024*1024)) > /proc/sys/vm/dirty_bytes
echo 0 > /proc/sys/vm/dirty_background_bytes
echo 0 > /proc/sys/vm/dirty_bytes
```

### fstab edit

```sh
# /etc/fstab: static file system information
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5)
#
# <file system> <mount point>  <type> <options>    <dump> <pass>
/dev/mapper/mordor--vg-root /        ext4  errors=remount-ro 0    1
# /boot was on /dev/sda1 during installation
UUID=xxx /boot      ext2  defaults    0    2
/dev/mapper/xxx--vg-swap_1 none      swap  sw       0    0
UUID="xxx" /xxx/xxx ext4 defaults,x-gvfs-show 0 0
```

### Viber install

```sh
cd ~/Downloads && wget <http://security.ubuntu.com/ubuntu/pool/main/o/openssl1.0/libssl1.0.0_1.0.2n-1ubuntu6.2_amd64.deb> && sudo dpkg -i libssl1.0.0_1.0.2n-1ubuntu6.2_amd64.deb
cd ~/Downloads && wget <https://download.cdn.viber.com/cdn/desktop/Linux/viber.deb>
sudo chmod +x viber.deb && sudo dpkg -i viber.deb
```

### GNS3 FOR DEBIAN BUSTER

```sh
sudo apt install -y python3-pip python3-pyqt5 python3-pyqt5.qtsvg python3-pyqt5.qtwebsockets qemu qemu-kvm qemu-utils libvirt-clients libvirt-daemon-system virtinst wireshark xtightvncviewer apt-transport-https ca-certificates curl gnupg2 software-properties-common
```

### gns3

```sh
deb <http://ppa.launchpad.net/gns3/ppa/ubuntu> bionic main
deb-src <http://ppa.launchpad.net/gns3/ppa/ubuntu> bionic main
deb <http://security.debian.org/debian-security> jessie/updates main contrib
sudo dpkg --add-architecture i386
sudo apt update && sudo apt upgrade
sudo apt install gns3-server gns3-gui gns3-iou
```

### add missing key

```sh
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AA8E81B4331F7F50
```

### cherrytree

```sh
deb <http://ppa.launchpad.net/giuspen/ppa/ubuntu> eoan main
deb-src <http://ppa.launchpad.net/giuspen/ppa/ubuntu> eoan main
<https://packages.debian.org/stretch/amd64/python-gtksourceview2/download>
```

### EWS

```sh
deb <http://deb.debian.org/debian/> buster-backports main
deb <http://ftp.de.debian.org/debian> buster-backports main

sudo apt update && sudo apt install evolution-ews -t buster-backports

<https://extensions.gnome.org/extension/615/appindicator-support/>
```

### Reduce PDF size

```sh
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=output.pdf input.pdf

  -dPDFSETTINGS=/screen lower quality, smaller size. (72 dpi)
  -dPDFSETTINGS=/ebook for better quality, but slightly larger pdfs. (150 dpi)
  -dPDFSETTINGS=/prepress output similar to Acrobat Distiller "Prepress Optimized" setting (300 dpi)
  -dPDFSETTINGS=/printer selects output similar to the Acrobat Distiller "Print Optimized" setting (300 dpi)
  -dPDFSETTINGS=/default selects output intended to be useful across a wide variety of uses, possibly at the expense of a larger output file
```

### install dictionaries

```sh
sudo apt install aspell-hr firefox-esr-l10n-hr hunspell-hr hyphen-hr libreoffice-l10n-hr myspell-hr aspell-de firefox-esr-l10n-de hunspell-de-de hyphen-de libreoffice-l10n-de
```

### Mounting vmware folders

```sh
sudo apt-get install open-vm-tools open-vm-tools-desktop
sudo apt-get install build-essential module-assistant linux-headers-virtual linux-image-virtual && dpkg-reconfigure open-vm-tools
vmware-hgfsclient
mkdir /mnt/hgfs/shared
sudo vmhgfs-fuse .host:/shared /mnt/hgfs/shared -o allow_other -o uid=1000
sudo nano /etc/fstab
```

### Use shared folders between VMWare guest and host

```sh
.host:/shared  /mnt/hgfs/shared  fuse.vmhgfs-fuse  defaults,allow_other,uid=1000   0  0
<https://medium.com/@alexandrerosseto/vmware-linux-how-to-share-folder-between-host-and-vm-62e63419ecbb>
```

## FIND

- How do you find all of the files owned by a user then copy those files to a temp folder?

```sh
find / -user user -exec cp {} /tmp \;

find /home/<user> -type f -exec grep -l <word> {} \; | xargs mv -t /home/<some-folder>/
```

- find all files with extension .gif

```sh
find /home/<user>/Downloads/ -type f -name "*.gif"
```

- Find all gif's and copy them

```sh
find ~/Downloads/ -type f -name "*.gif" -exec cp {} GIFS/ \;
```

- find and move all .pdf files to somewhere

```sh
find / -type f -name "*.pdf" -exec mv {} /home/<move-dir>/ 2>cp.err \;
```

- If you also want to see differences for files that may not exist in either directory:

```sh
diff --brief --recursive --new-file dir1/ dir2/ # GNU long options
diff -qrN /media/baggins/Mel - externi /media/baggins/My Book/MEL/externi-disk-backup # common short options
```

## GREP

- When we execute the grep command with specified pattern, if its is matched, then it will display the line of file containing the pattern without modifying the contents of existing file.
In this tutorial we will learn how to use Linux grep command with 14 practical examples,

### Example:1

- Search the pattern (word) in a file
- Search the “linuxtechi” word in the file /etc/passwd file

```sh
root@Linux-world:~# grep linuxtechi /etc/passwd
linuxtechi:x:1000:1000:linuxtechi,,,:/home/linuxtechi:/bin/bash
```

### Example:2

- Search the pattern in the multiple files.

```sh
root@Linux-world:~# grep linuxtechi /etc/passwd /etc/shadow /etc/gshadow
/etc/passwd:linuxtechi:x:1000:1000:linuxtechi,,,:/home/linuxtechi:/bin/bash
/etc/shadow:linuxtechi:$6$DdgXjxlM$4flz4JRvefvKp0DG6re:16550:0:99999:7:::/etc/gshadow:adm:*::syslog,linuxtechi
/etc/gshadow:cdrom:*::linuxtechi
/etc/gshadow:sudo:*::linuxtechi
/etc/gshadow:dip:*::linuxtechi
/etc/gshadow:plugdev:*::linuxtechi
/etc/gshadow:lpadmin:!::linuxtechi
/etc/gshadow:linuxtechi:!::
/etc/gshadow:sambashare:!::linuxtechi
```

### Example:3

- List the name of those files which contain a specific pattern using -l option.

```sh
root@Linux-world:~# grep -l linuxtechi /etc/passwd /etc/shadow /etc/fstab /etc/mtab
/etc/passwd
/etc/shadow
```

### Example:4

- Search the pattern in the file along with associated line number(s) using the -n option

```sh
root@Linux-world:~# grep -n linuxtechi /etc/passwd
39:linuxtechi:x:1000:1000:linuxtechi,,,:/home/linuxtechi:/bin/bash
root@Linux-world:~#root@Linux-world:~# grep -n root /etc/passwd /etc/shadow
```

### Example:5

- Print the line excluding the pattern using -v option
- List all the lines of the file /etc/passwd that does not contain specific word “linuxtechi”.

```sh
root@Linux-world:~# grep -v linuxtechi /etc/passwd
```

### Example:6

- Display all the lines that starts with specific pattern using ^ symbol
Bash shell treats caret symbol (^) as a special character which marks the beginning of line or a word.
- Let’s display the lines which starts with “root” word in the file /etc/passwd.

```sh
root@Linux-world:~# grep ^root /etc/passwd
root:x:0:0:root:/root:/bin/bash
```

### Example:7

- Display all the lines that ends with specific pattern using $ symbol
- List all the lines of /etc/passwd that ends with “bash” word.

```sh
root@Linux-world:~# grep bash$ /etc/passwd
root:x:0:0:root:/root:/bin/bash
linuxtechi:x:1000:1000:linuxtechi,,,:/home/linuxtechi:/bin/bash
root@Linux-world:~#Bash shell treats dollar ($) symbol as a special character which marks the end of line or word.
```

### Example:8

- Search the pattern recursively using -r option

```sh
root@Linux-world:~# grep -r linuxtechi /etc/
/etc/subuid:linuxtechi:100000:65536
/etc/group:adm:x:4:syslog,linuxtechi
/etc/group:cdrom:x:24:linuxtechi
/etc/group:sudo:x:27:linuxtechi
/etc/group:dip:x:30:linuxtechi
/etc/group:plugdev:x:46:linuxtechi
/etc/group:lpadmin:x:115:linuxtechi
/etc/group:linuxtechi:x:1000:
/etc/group:sambashare:x:131:linuxtechi
/etc/passwd-:linuxtechi:x:1000:1000:linuxtechi,,,:/home/linuxtechi:/bin/bash
/etc/passwd:linuxtechi:x:1000:1000:linuxtechi,,,:/home/linuxtechi:/bin/bash
# Above command will search linuxtechi in the “/etc” directory recursively.
```

### Example:9

- Search all the empty or blank lines of a file using grep

```sh
root@Linux-world:~# grep ^$ /etc/shadow
root@Linux-world:~# As there is no empty line in /etc/shadow file , so nothing is displayed.
```

### Example:10

- Search the pattern using ‘grep -i’ option
- -i option in the grep command ignores the letter case i.e it will not discriminate upper case or lower case letters while searching
- Lets take an example , i want to search “LinuxTechi” word in the passwd file.

```sh
nextstep4it@localhost:~$ grep -i LinuxTechi /etc/passwd
linuxtechi:x:1001:1001::/home/linuxtechi:/bin/bash
```

- Note : In grep command,we can also do the search based on exact word using ‘-w’ option, example is shown below,

```sh
grep -w cook /mnt/my_dish.txt
```

- Above command will search and look for the lines which have “cook” word. It wont give results which has cooking.

### Example:11

- Search multiple patterns using -e option
- For example i want to search ‘linuxtechi’ and ‘root’ word in a single grep command , then using -e option we can search multiple patterns.

```sh
root@Linux-world:~# grep -e "linuxtechi" -e "root" /etc/passwd
root:x:0:0:root:/root:/bin/bash
linuxtechi:x:1000:1000:linuxtechi,,,:/home/linuxtechi:/bin/bash
```

or

```sh
root@Linux-world:~# grep -E "linuxtechi|root" /etc/passwd
```

### Example:12

- Getting Search pattern from a file using “grep -f”
- First create a search pattern file “grep_pattern” in your current working directory.
- In my case i have put the below contents.

```sh
root@Linux-world:~# cat grep_pattern
^linuxtechi
root
false$
root@Linux-world:~# Now try to search using grep_pattern file.
root@Linux-world:~# grep -f grep_pattern /etc/passwd
```

### Example:13

- Count the number of matching patterns using -c option
- Let take the above example, we can count the number of matching patterns using -c option in grep command.

```sh
root@Linux-world:~# grep -c -f grep_pattern /etc/passwd
22
```

### Example:14

- Display N number of lines before & after pattern matching
- a) Display Four lines before pattern matching using -B option

```sh
root@Linux-world:~# grep -B 4 "games" /etc/passwd
```

- b) Display Four lines after pattern matching using -A option

```sh
root@Linux-world:~# grep -A 4 "games" /etc/passwd
```

- c) Display Four lines around the pattern matching using -C option

```sh
root@Linux-world:~# grep -C 4 "games" /etc/passwd
```

## VIM

- Invoke external binaries from within vim  

```sh
:!r ip route show | grep default | cut -f 3 -d " "
```

- Insert existing file  

```sh
:r /etc/passwd
```

- Search and substitute (replace)  

```sh
:%s/old/new/g
:%s/old/new/gc --> to be prompted for a change
```
