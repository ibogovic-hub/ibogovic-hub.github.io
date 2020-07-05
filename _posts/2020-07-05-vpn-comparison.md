> # Point of this page is to quickly compare few protocols and solutions related to VPN technology

## PPTP

#### (+) "Pros"
    + Very fast
    + Native Windows Support
    
#### (-) "Cons"
    - Not reliable connection
    - Issues with some routers
    - Can be easily blocked
    - Not secure

Usability | Configuration | Security | Future Development
--------- | ------------- | -------- | ------------------
 6 | 3 | 2 | No ?

---

## IPSec / IKEv2

#### (+) "Pros"  
    + Very secure
    + Insane connection speeds
    + Very fast!
    + Most operating system supports IKEv2
    
#### (-) * Red "Cons"
    - Not every VPN supports IKEv2
    - Can be trickier to configure
    - Could be exploited
    - Can be easily blocked

Usability | Configuration | Security | Future Development
--------- | ------------- | -------- | ------
 8 | 9 | 7 | Yes

---
    
## OpenVPN

#### (+) "Pros"
    + Very secure
    + Very fast
    + Open source design
    + Industry standard VPN
    + Works great with Routers
    + Can bypass firewalls easily
    
#### (-) "Cons"
    - Not supported completely on IOS
    - A bit "manual work" to configure
    - Slower connection times that IKEv2

Usability | Configuration | Security | Future Development
--------- | ------------- | -------- | ------
 9 | 9 | 8 | Yes

---
    
## WireGuard  

- enterprise ready?  
- WireGuard is currently the most interesting upcoming technology for VPN solutions.  
- WireGuard is a new VPN protocol that aims to be a full replacement of OpenVPN and IPSec.  
- It is based on established technologies and follows a modern and simple principle.

More info related to WireGuard can be found [HERE](https://www.the-digital-life.com/en/wireguard-vs-openvpn-and-ipsec-which-one-is-the-best/)

#### (+) "Pros"
    + Huge potential for Mobile (battery, better speed etc)
    + Router support seems promising
    + Great at reconnecions
    + Suppose to be the fastest
    + Smaller more efficient codebase that is superior.
    
#### (-) "Cons"
    - Limited supprot for VPNs
    - Not read for secure use...
    - May succomv to traffic shaping.
    - no OS support (at the moment.)

Usability | Configuration | Security | Future Development
--------- | ------------- | -------- | ------
 9 | 5 | 9 | Yes