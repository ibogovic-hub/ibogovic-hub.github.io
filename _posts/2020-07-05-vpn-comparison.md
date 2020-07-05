Point of this page is to quickly compare few protocols and solutions related to VPN technology

> More detailed info related to vpn comparison can be found on [THIS](https://en.wikipedia.org/wiki/Comparison_of_virtual_private_network_services) Wiki page...


## [PPTP](https://en.wikipedia.org/wiki/Point-to-Point_Tunneling_Protocol)  
- General:  
    - The Point-to-Point Tunneling Protocol (PPTP) is an obsolete method for implementing virtual private networks. PPTP has many well known security issues.  
    - PPTP uses a TCP control channel and a Generic Routing Encapsulation tunnel to encapsulate PPP packets.  
    - Many modern VPNs use various forms of UDP for this same functionality.  
    - The PPTP specification does not describe encryption or authentication features and relies on the Point-to-Point Protocol being tunneled to implement any and all security functionalities.  
    - The PPTP implementation that ships with the Microsoft Windows product families implements various levels of authentication and encryption natively as standard features of the Windows PPTP stack.  
    - The intended use of this protocol is to provide security levels and remote access levels comparable with typical VPN products.  
- Security:  
    - PPTP has been the subject of many security analyses and serious security vulnerabilities have been found in the protocol.  
    
#### (+) "Pros"
    + Very fast
    + Native Windows Support
    
#### (-) "Cons"
    - Not reliable connection
    - Issues with some routers
    - Can be easily blocked
    - Not secure

Usability | Configuration | Security | Future Development
:---: | :---: | :---: | :---:
 6 | 3 | 2 | obsolete

---

## [IPSec / IKEv2](https://en.wikipedia.org/wiki/IPsec)  

- General:
    - is a secure network protocol suite that authenticates and encrypts the packets of data to provide secure encrypted communication between two computers over an Internet Protocol network.  
    - open standard  
    
- Example protocol stack and corresponding layers  

Protocol | Layer
:---: | :---:
HTTP | Application
TCP	| Transport
IP | Internet or network
Ethernet | Link or data link
IEEE | 802.3u Physical

#### (+) "Pros"  
    + Very secure
    + Insane connection speeds
    + Very fast!
    + Most operating system supports IKEv2
    
#### (-) "Cons"
    - Not every VPN supports IKEv2
    - Can be trickier to configure
    - Could be exploited
    - Can be easily blocked

Usability | Configuration | Security | Future Development
:---: | :---: | :---: | :---:
 8 | 8 | 7 | Yes

---
    
## [OpenSSL](https://en.wikipedia.org/wiki/OpenSSL)  

- **General:**  
    - OpenSSL is a software library for applications that secure communications over computer networks against eavesdropping or need to identify the party at the other end.  
    - It is widely used by Internet servers, including the majority of HTTPS websites.
    - OpenSSL contains an open-source implementation of the SSL and TLS protocols.  
    - 

- **Security:**  
    - OpenSSL supports a number of different cryptographic algorithms:  
        - **Ciphers** : --> *AES, Blowfish, Camellia, Chacha20, Poly1305, SEED, CAST-128, DES, IDEA, RC2, RC4, RC5, Triple DES, GOST 28147-89, SM4*
        - **Cryptographic hash functions** : --> *MD5, MD4, MD2, SHA-1, SHA-2, SHA-3, RIPEMD-160, MDC-2, GOST R 34.11-94, BLAKE2, Whirlpool, SM3*
        - **Public-key cryptography** : --> *RSA, DSA, Diffie–Hellman key exchange, Elliptic curve, X25519, Ed25519, X448, Ed448, GOST R 34.10-2001, SM2*

Usability | Configuration | Security | Future Development | Licence 
:---: | :---: | :---: | :---: | :---:
10 | 8 | 8 | Yes | OpenSSL / Apache 1,0

## [OpenVPN](https://en.wikipedia.org/wiki/OpenVPN)

- **General:**
    - OpenVPN is open-source commercial software that implements virtual private network (VPN) techniques to create secure point-to-point or site-to-site connections in routed or bridged configurations and remote access facilities.  
    - It uses a custom security protocol that utilizes SSL/TLS for key exchange.  
    - It is capable of traversing network address translators (NATs) and firewalls.  
    - OpenVPN allows peers to authenticate each other using pre-shared secret keys, certificates or username/password.
    - 
    
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

Usability | Configuration | Security | Future Development | Licence 
:---: | :---: | :---: | :---: | :---:
 9 | 7 | 8 | Yes | GPL

---
    
## [WireGuard](https://www.wireguard.com/)  

- General:  
    - WireGuard® is an extremely simple yet fast and modern VPN that utilizes state-of-the-art cryptography.  
    - It aims to be faster, simpler, leaner, and more useful than IPsec, while avoiding the massive headache.  
    - It intends to be considerably more performant than OpenVPN.  
    - WireGuard is designed as a general purpose VPN for running on embedded interfaces and super computers alike, fit for many different circumstances.  
    - Initially released for the Linux kernel, it is now cross-platform (Windows, macOS, BSD, iOS, Android) and widely deployable.  
    - It is currently under heavy development, but already it might be regarded as the most secure, easiest to use, and simplest VPN solution in the industry.  
    

More info related to WireGuard can be found [HERE](https://www.the-digital-life.com/en/wireguard-vs-openvpn-and-ipsec-which-one-is-the-best/)

#### (+) "Pros"
    + Huge potential for Mobile (battery, better speed etc)
    + Router support seems promising
    + Great at reconnecions
    + Suppose to be the fastest
    + Smaller more efficient codebase that is superior.
    
#### (-) "Cons"
    - Limited supprot for VPNs
    - Not ready for secure use...
    - Enterprise ready ?
    - no OS support (at the moment.)

Usability | Configuration | Security | Future Development
:---: | :---: | :---: | :---:
 9 | 3 | 9 | Yes