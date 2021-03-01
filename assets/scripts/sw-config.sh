```bash
#!/usr/bin/expect -f
 
 set ip [lindex $argv 0];
 send_user ip

# Set variables
 set hostname $ip
 set username ###########
 set password ###########
 
# Log results
 log_file -a /home/<user>/logs/backup.log
 
# Announce which device we are working on and at what time
 send_user "\n"
 send_user ">>>>>  Working on $hostname @ [exec date] <<<<<\n"
 send_user "\n"
 
# Don't check keys
 spawn ssh -o StrictHostKeyChecking=no $username\@$hostname
 
# Allow this script to handle ssh connection issues
 expect {
 timeout { send_user "\nTimeout Exceeded - Check Host\n"; exit 1 }
 eof { send_user "\nSSH Connection To $hostname Failed\n"; exit 1 }
 "*#" {}
 "*assword:" {
 send "$password\n"
 }
 }
 
# If we're not already in enable mode, get us there
 expect {
 default { send_user "\nEnable Mode Failed - Check Password\n"; exit 1 }
 "*#" {}
 "*>" {
 send "enable\n"
 expect "*assword"
 send "$enablepassword\n"
 expect "*#"
 }
 }
 
# Let's go to configure mode
 #end "conf t\n"
 #expect "(config)#"
 
# Enter your commands here. Examples listed below
 send "copy flash:/startup-config.conf tftp://172.100.100.1:69/test.conf\n"
 expect "#"
 send "exit\n"
 expect ":~\$"
 exit
```