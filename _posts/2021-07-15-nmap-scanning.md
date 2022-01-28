---
title: nmap scanning
tags: nmap
---

### basic scan of one IP
```
nmap 192.168.1.1
```

### basic scan of subnet
```
nmap 192.168.1.0/24
```
### create and scan from a file
```
nmap -iL test.txt
```

### random scan and exclude IP
```
nmap -iR 50
```

### exclude IP
```
nmap 192.168.1.0/24 --exclude 192.168.1.100
```

## export results to a file
### txt
```
nmap 192.168.1.0/24 -oN /root/output.txt
```

### xml 
```
nmap 192.168.1.0/24 -oX /root/output.xml
```

### grepable file
```
nmap 192.168.1.0/24 -oG /root/output
```

### all format export
```
nmap 192.168.1.0/24 -oA /root/output
```

## Nmap Examples
- Basic Nmap scanning examples, often used at the first stage of enumeration.
```
nmap -sP 10.0.0.0/24
```

- Ping scans the network, listing machines that respond to ping.

```
nmap -p 1-65535 -sV -sS -T4 target
```

- Full TCP port scan using with service version detection - usually my first scan, I find T4 more accurate than T5 and still "pretty quick".

```
nmap -v -sS -A -T4 target
```

- Prints verbose output, runs stealth syn scan, T4 timing, OS and version detection + traceroute and scripts against target services.

```
nmap -v -sS -A -T5 target
```

- Prints verbose output, runs stealth syn scan, T5 timing, OS and version detection + traceroute and scripts against target services.

```
nmap -v -sV -O -sS -T5 target
```

- Prints verbose output, runs stealth syn scan, T5 timing, OS and version detection.

```
nmap -v -p 1-65535 -sV -O -sS -T4 target
```

- Prints verbose output, runs stealth syn scan, T4 timing, OS and version detection + full port range scan.

```
nmap -v -p 1-65535 -sV -O -sS -T5 target
```

- Prints verbose output, runs stealth syn scan, T5 timing, OS and version detection + full port range scan.


### Nmap scan from file
```
nmap -iL ip-addresses.txt
```

- Scans a list of IP addresses, you can add options before / after.

### Nmap output formats
```
nmap -sV -p 139,445 -oG grep-output.txt 10.0.1.0/24
```

- Outputs "grepable" output to a file, in this example Netbios servers.
- E.g, The output file could be grepped for "Open".

nmap -sS -sV -T5 10.0.1.99 --webxml -oX - | xsltproc --output file.html -

- Export nmap output to HTML report.

### Nmap Netbios Examples
```
nmap -sV -v -p 139,445 10.0.0.1/24
```

- Find all Netbios servers on subnet

```
nmap -sU --script nbstat.nse -p 137 target
```

- Nmap display Netbios name

```
nmap --script-args=unsafe=1 --script smb-check-vulns.nse -p 445 target
```

- Nmap check if Netbios servers are vulnerable to MS08-067

>***--script-args=unsafe=1 has the potential to crash servers / services
Becareful when running this command.***

### Nmap Nikto Scan
```
nmap -p80 10.0.1.0/24 -oG - | nikto.pl -h -
```

- Scans for http servers on port 80 and pipes into Nikto for scanning.

```
nmap -p80,443 10.0.1.0/24 -oG - | nikto.pl -h -
```

- Scans for http/https servers on port 80, 443 and pipes into Nikto for scanning.

### Script Scan
```
-sC
```
- equivalent to --script=default
```
--script="Lua scripts"
```
- "Lua scripts" is a comma separated list of directories, script-files or script-categories
```
--script-args=n1=v1,[n2=v2,...]
```
- provide arguments to scripts
```
-script-args-file=filename
```
- provide NSE script args in a file
```
--script-trace
```
- Show all data sent and received
```
--script-updatedb
```
- Update script database
```
--script-help="Lua scripts"
```
- Show help about scripts

### OS Detection
```
-O
```
- Enable OS Detection
```
--osscan-limit
```
- Limit OS detection to promising targets
```
--osscan-guess
```
- Guess OS more aggressively

### Timing and Performance
- Options which take TIME are in seconds, or append 'ms' (milliseconds), 's' (seconds), 'm' (minutes), or 'h' (hours) to the value (e.g. 30m).
```
-T 0-5
```
- Set timing template - higher is faster (less accurate)
```
--min-hostgroup SIZE 
--max-hostgroup SIZE
```
- Parallel host scan group sizes
```
--min-parallelism NUMPROBES 
--max-parallelism NUMPROBES
```
- Probe parallelization
```
--min-rtt-timeout TIME
--max-rtt-timeout TIME
--initial-rtt-timeout TIME
```
- Specifies probe round trip time
```
--max-retries TRIES
```
- Caps number of port scan probe retransmissions
```
--host-timeout TIME
```
- Give up on target after this long
```
--scan-delay TIME 
--max-scan-delay TIME
```
- Adjust delay between probes
```
--min-rate NUMBER
```
- Send packets no slower than NUMBER per second
```
--max-rate NUMBER
```
- Send packets no faster than NUMBER per second

### Firewalls IDS Evasion and Spoofing
```
-f; --mtu VALUE
```
- Fragment packets (optionally w/given MTU)
```
-D decoy1,decoy2,ME
```
- Cloak a scan with decoys
```
-S IP-ADDRESS
```
- Spoof source address
```
-e IFACE
```
- Use specified interface
```
-g PORTNUM
--source-port PORTNUM
```
- Use given port number
```
--proxies url1,[url2],...
```
- Relay connections through HTTP / SOCKS4 proxies
```
--data-length NUM
```
- Append random data to sent packets
```
--ip-options OPTIONS
```
- Send packets with specified ip options
```
--ttl VALUE
```
- Set IP time to live field
```
--spoof-mac ADDR/PREFIX/VENDOR
```
- Spoof NMAP MAC address
```
--badsum
```
- Send packets with a bogus TCP/UDP/SCTP checksum

### Nmap Output Options
```
-oN
```
- Output Normal
```
-oX
```
- Output to XML
```
-oS
```
- Script Kiddie / 1337 speak... sigh
```
-oG
```
- Output greppable - easy to grep nmap output
```
-oA BASENAME
```
- Output in the three major formats at once
```
-v
```
- Increase verbosity level use -vv or more for greater effect
```
-d
```
- Increase debugging level use -dd or more for greater effect
```
--reason
```
- Display the reason a port is in a particular state
```
--open
```
- Only show open or possibly open ports
```
--packet-trace
```
- Show all packets sent / received
```
--iflist
```
- Print host interfaces and routes for debugging
```
--log-errors
```
- Log errors/warnings to the normal-format output file
```
--append-output
```
- Append to rather than clobber specified output files
```
--resume FILENAME
```
- Resume an aborted scan
```
--stylesheet PATH/URL
```
- XSL stylesheet to transform XML output to HTML
```
--webxml
```
- Reference stylesheet from Nmap.Org for more portable XML
```
--no-stylesheet
```
- Prevent associating of XSL stylesheet w/XML output

## Nmap Enumeration Examples
- The following are real world examples of Nmap enumeration.

### Enumerating Netbios
- The following example enumerates Netbios on the target networks, the same process can be applied to other services by modifying ports / NSE scripts.
- Detect all exposed Netbios servers on the subnet.

### Nmap find exposed Netbios servers
```
:# nmap -sV -v -p 139,445 10.0.1.0/24


Starting Nmap 6.47 ( http://nmap.org ) at 2014-12-11 21:26 GMT
Nmap scan report for nas.decepticons 10.0.1.12
Host is up (0.014s latency).

PORT STATE SERVICE VERSION
139/tcp open netbios-ssn Samba smbd 3.X (workgroup: MEGATRON)
445/tcp open netbios-ssn Samba smbd 3.X (workgroup: MEGATRON)

Service detection performed. Please report any incorrect results at http://nmap.org/submit/ .

Nmap done: 256 IP addresses (1 hosts up) scanned in 28.74 seconds
```

### Nmap find Netbios name.
```
:# nmap -sU --script nbstat.nse -p 137 10.0.1.12


Starting Nmap 6.47 ( http://nmap.org ) at 2014-12-11 21:26 GMT
Nmap scan report for nas.decepticons 10.0.1.12
Host is up (0.014s latency).

PORT STATE SERVICE VERSION
137/udp open netbios-ns

Host script results:
|_nbstat: NetBIOS name: STARSCREAM, NetBIOS user: unknown, NetBIOS MAC: unknown (unknown)
Nmap done: 256 IP addresses (1 hosts up) scanned in 28.74 seconds

```
### Check if Netbios servers are vulnerable to MS08-067
```
:# nmap --script-args=unsafe=1 --script smb-check-vulns.nse -p 445 10.0.0.1


Nmap scan report for ie6winxp.decepticons (10.0.1.1)
Host is up (0.00026s latency).
PORT STATE SERVICE
445/tcp open microsoft-ds
Host script results:
| smb-check-vulns:
| MS08-067: VULNERABLE
| Conficker: Likely CLEAN
| regsvc DoS: NOT VULNERABLE
| SMBv2 DoS (CVE-2009-3103): NOT VULNERABLE
|_ MS07-029: NO SERVICE (the Dns Server RPC service is inactive)
Nmap done: 1 IP address (1 host up) scanned in 5.45 seconds
```
- Need to know the internal AD Domain name from outside? Find their Skype or Lync server and then:
```
nmap -p443 --script http-ntlm-info --script-args http-ntlm-info.root=/WebTicket/WebTicketService.svc some.domain.com
```
```
nmap -p 1-65535 -sV -sS -T4 some.domain.com
```
- Full TCP port scan using with service version detection
- Usually my first scan, I find T4 more accurate than T5 and still "pretty quick".
```
nmap -v -sS -A -T4 target
```
- Prints verbose output, runs stealth syn scan, T4 timing, OS and version detection + traceroute and scripts against target services  
```
nmap -v -p 1-65535 -sV -O -sS -T4 --webxml -oX - | xsltproc --output file.html - 
```
- Prints verbose output, runs stealth syn scan, T4 timing, OS and version detection + full port range scan.
```
nmap -T4 -A -v
```
### Basic Scanning Techniques
Scan a single target --> ***nmap [target]***  
Scan multiple targets --> ***nmap [target1,target2,etc]***  
Scan a list of targets —-> ***nmap -iL [list.txt]***  
Scan a range of hosts —-> ***nmap [range of IP addresses]***  
Scan an entire subnet —-> ***nmap [IP address/cdir]***  
Scan random hosts —-> ***nmap -iR [number]***  
Excluding targets from a scan --> ***nmap [targets] –exclude [targets]***  
Excluding targets using a list --> ***nmap [targets] –excludefile [list.txt]***  
Perform an aggressive scan --> ***nmap -A [target]***  
Scan an IPv6 target --> ***nmap -6 [target]***  
### Discovery Options  
Perform a ping scan only --> ***nmap -sP [target]***  
Don’t ping --> ***nmap -PN [target]***  
TCP SYN Ping --> ***nmap -PS [target]***  
TCP ACK ping —-> ***nmap -PA [target]***  
UDP ping —-> ***nmap -PU [target]***  
SCTP Init Ping --> ***nmap -PY [target]***  
ICMP echo ping —-> ***nmap -PE [target]***  
ICMP Timestamp ping --> ***nmap -PP [target]***  
ICMP address mask ping --> ***nmap -PM [target]***  
IP protocol ping —-> ***nmap -PO [target]***  
ARP ping --> ***nmap -PR [target]***  
Traceroute --> ***nmap –traceroute [target]***  
Force reverse DNS resolution --> ***nmap -R [target]***  
Disable reverse DNS resolution --> ***nmap -n [target]***  
Alternative DNS lookup --> ***nmap –system-dns [target]***  
Manually specify DNS servers --> ***nmap –dns-servers [servers] [target]***  
Create a host list —-> ***nmap -sL [targets]***  
### Advanced Scanning Options  
TCP SYN Scan --> ***nmap -sS [target]***  
TCP connect scan —-> ***nmap -sT [target]***  
UDP scan —-> ***nmap -sU [target]***  
TCP Null scan —-> ***nmap -sN [target]***  
TCP Fin scan --> ***nmap -sF [target]***  
Xmas scan —-> ***nmap -sX [target]***  
TCP ACK scan --> ***nmap -sA [target]***  
Custom TCP scan —-> ***nmap –scanflags [flags] [target]***  
IP protocol scan —-> ***nmap -sO [target]***  
Send Raw Ethernet packets —-> ***nmap –send-eth [target]***  
Send IP packets —-> ***nmap –send-ip [target]***  
### Port Scanning Options  
Perform a fast scan --> ***nmap -F [target]***  
Scan specific ports —-> ***nmap -p [ports] [target]***  
Scan ports by name —-> ***nmap -p [port name] [target]***  
Scan ports by protocol —-> ***nmap -sU -sT -p U:[ports],T:[ports] [target]***   
Scan all ports —-> ***nmap -p “*” [target]***  
Scan top ports —–> ***nmap –top-ports [number] [target]***  
Perform a sequential port scan —-> ***nmap -r [target]***  
### Version Detection  
Operating system detection —-> ***nmap -O [target]***  
Submit TCP/IP Fingerprints —-> ***http://www.nmap.org/submit/***  
Attempt to guess an unknown —-> ***nmap -O –osscan-guess [target]***  
Service version detection —-> ***nmap -sV [target]***  
Troubleshooting version scans —-> ***nmap -sV –version-trace [target]***  
Perform a RPC scan —-> ***nmap -sR [target]***  
### Timing Options  
Timing Templates —-> ***nmap -T [0-5] [target]***  
Set the packet TTL —-> ***nmap –ttl [time] [target]***  
Minimum of parallel connections —-> ***nmap –min-parallelism [number] [target]***  
Maximum of parallel connection —-> ***nmap –max-parallelism [number] [target]***  
Minimum host group size —–> ***nmap –min-hostgroup [number] [targets]***  
Maximum host group size —-> ***nmap –max-hostgroup [number] [targets]***  
Maximum RTT timeout —–> ***nmap –initial-rtt-timeout [time] [target]***  
Initial RTT timeout —-> ***nmap –max-rtt-timeout [TTL] [target]***  
Maximum retries —-> ***nmap –max-retries [number] [target]***  
Host timeout —-> ***nmap –host-timeout [time] [target]***  
Minimum Scan delay —-> ***nmap –scan-delay [time] [target]***  
Maximum scan delay —-> ***nmap –max-scan-delay [time] [target]***  
Minimum packet rate —-> ***nmap –min-rate [number] [target]***  
Maximum packet rate —-> ***nmap –max-rate [number] [target]***  
Defeat reset rate limits —-> ***nmap –defeat-rst-ratelimit [target]***  
### Firewall Evasion Techniques  
Fragment packets —-> ***nmap -f [target]***  
Specify a specific MTU —-> ***nmap –mtu [MTU] [target]***  
Use a decoy —-> ***nmap -D RND: [number] [target]***  
Idle zombie scan --> ***nmap -sI [zombie] [target]***  
Manually specify a source port —-> ***nmap –source-port [port] [target]***  
Append random data —-> ***nmap –data-length [size] [target]***  
Randomize target scan order —-> ***nmap –randomize-hosts [target]***  
Spoof MAC Address —-> ***nmap –spoof-mac [MAC|0|vendor] [target]***  
Send bad checksums —-> ***nmap –badsum [target]***  
### Output Options  
Save output to a text file —-> ***nmap -oN [scan.txt] [target]***  
Save output to a xml file --> ***nmap -oX [scan.xml] [target]***  
Grepable output —-> ***nmap -oG [scan.txt] [target]***  
Output all supported file types —-> ***nmap -oA [path/filename] [target]***  
Periodically display statistics —-> ***nmap –stats-every [time] [target]***  
133t output —-> ***nmap -oS [scan.txt] [target]***  
### Troubleshooting and debugging  
Help --> ***nmap -h***  
Display Nmap version —-> ***nmap -V***  
Verbose output —-> ***nmap -v [target]***  
Debugging —-> ***nmap -d [target]***  
Display port state reason —-> ***nmap –reason [target]***  
Only display open ports —-> ***nmap –open [target]***  
Trace packets --> ***nmap –packet-trace [target]***  
Display host networking --> ***nmap –iflist***  
Specify a network interface --> ***nmap -e [interface] [target]***  
### Nmap Scripting Engine  
Execute individual scripts --> ***nmap --script [script.nse] [target]***  
Execute multiple scripts —-> ***nmap --script [expression] [target]***  

> Script categories —-> all, auth, default, discovery, external, intrusive, malware, safe, vuln  
  
Execute scripts by category —-> ***nmap --script [category] [target]***  
Execute multiple scripts categories —-> ***nmap --script [category1,category2, etc]***  
Troubleshoot scripts —-> ***nmap --script [script] --script-trace [target]***  
Update the script database —-> ***nmap --script-updatedb***  
### Ndiff
Comparison using Ndiff —-> ***ndiff [scan1.xml] [scan2.xml]***  
Ndiff verbose mode —-> ***ndiff -v [scan1.xml] [scan2.xml]***  
XML output mode —-> ***ndiff –xml [scan1.xm] [scan2.xml]***  
```
nmap -PT -P0 -sT -v -v IP
nmap -sT -P0 -O -v -v -T Insane IP
```

### EXAMPLES:  
```
nmap -v -A boweaver.com
nmap -v -sn 192.168.0.0/16 10.0.0.0/8
nmap -v -iR 10000 -Pn -p 80
```