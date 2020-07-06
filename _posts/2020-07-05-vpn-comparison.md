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
    + Just about every platform supports it
    
#### (-) "Cons"
    - Not reliable connection
    - Does not support Perfect Forward Secrecy
    - Can be easily blocked
    - Not secure

Usability | Configuration | Security | Future Development
:---: | :---: | :---: | :---:
 4<sup>[1](#table)</sup> | 2<sup>[2](#table)</sup> | 1 <sup>[3](#table)</sup> | obsolete

---

## [IPSec / IKEv2](https://en.wikipedia.org/wiki/IPsec)  

- **General:**
    - is a secure network protocol suite that authenticates and encrypts the packets of data to provide secure encrypted communication between two computers over an Internet Protocol network.  
    - open standard  
    - What makes IKEv2 stand out is its mobility.  
    - It is specifically developed for mobile users in mind, and because of its support for the MOBIKE (Mobility and Multihoming) protocol, it is extremely resilient to network changes.  
    
- Example protocol stack and corresponding layers  

Protocol | Layer
:---: | :---:
HTTP | Application
TCP	| Transport
IP | Internet or network
Ethernet | Link or data link
IEEE | 802.3u Physical

- **Security:**
    - *Cryptographic algorithms defined for use with IPsec include:*  
        - HMAC-SHA1/SHA2 for integrity protection and authenticity.  
        - TripleDES-CBC for confidentiality  
        - AES-CBC for confidentiality.  
        - AES-GCM providing confidentiality and authentication together efficiently.  
        - ChaCha20 + Poly1305 providing confidentiality and authentication together efficiently.  
    
    - *Key exchange algorithms:*  
        - Diffie-Hellman (RFC 3526)  
        - ECDH (RFC 4753)  
    
    - *Authentication algorithms:*  
        - RSA  
        - ECDSA (RFC 4754)  
        - PSK (RFC 6617)  

#### (+) "Pros"  
    + Arguably the fastest VPN protocol
    + Very stable and not prone to lost connections when switching network.
    + Supports a wide range of cryptographic algorithms
    + Easy to setup
    + Supports Perfect Forward Secrecy
    
#### (-) "Cons"
    - Not supported by many platforms
    - Although other systems do support it, it does not work as well as it does on Windows.
    - Could be exploited
    - Can be easily blocked

Usability | Configuration | Security | Future Development | Licence | Project Duration 
:---: | :---: | :---: | :---: | :---: | :---:
 8<sup>[1](#table)</sup> | 7<sup>[2](#table)</sup> | 9<sup>[3](#table)</sup> | Yes | -- | 1998 -->

---

## [OpenSSL](https://www.openssl.org/)  

- **General:**  
    - OpenSSL is a software library for applications that secure communications over computer networks against eavesdropping or need to identify the party at the other end.  
    - It is widely used by Internet servers, including the majority of HTTPS websites.
    - OpenSSL contains an open-source implementation of the SSL and TLS protocols.  


- **Security:**  
    - OpenSSL supports a number of different cryptographic algorithms:  
        - **Ciphers** : --> *AES, Blowfish, Camellia, Chacha20, Poly1305, SEED, CAST-128, DES, IDEA, RC2, RC4, RC5, Triple DES, GOST 28147-89, SM4*
        - **Cryptographic hash functions** : --> *MD5, MD4, MD2, SHA-1, SHA-2, SHA-3, RIPEMD-160, MDC-2, GOST R 34.11-94, BLAKE2, Whirlpool, SM3*
        - **Public-key cryptography** : --> *RSA, DSA, Diffie–Hellman key exchange, Elliptic curve, X25519, Ed25519, X448, Ed448, GOST R 34.10-2001, SM2*

- **Latest stabile release** ==> ***1.1.1g (April 21, 2020)***

#### (+) "Pros"  
    + Identity Verification
    + Data Integrity
    + Trust 

#### (-) "Cons"
    - HTTPS can cause delays (older hardware)
    - SSL certificate requirements
    - Mixed mode issues (loading external sites that have unencrypted content)
    - Proxy Caching Problems

Usability | Configuration | Security | Future Development | Licence | Project Duration 
:---: | :---: | :---: | :---: | :---: | :---:
9<sup>[1](#table)</sup> | 8<sup>[2](#table)</sup> | 8<sup>[3](#table)</sup> | Yes | OpenSSL / Apache 1,0 | 1998 --> 

## [OpenVPN](https://en.wikipedia.org/wiki/OpenVPN)

- **General:**
    - OpenVPN is one of the most popular and well-received VPN implementations. It is an Open Source VPN solution with high stability and excellent security.  
    - It uses a custom security protocol that utilizes SSL/TLS for key exchange.  
    - It is capable of traversing network address translators (NATs) and firewalls.  
    - OpenVPN allows peers to authenticate each other using pre-shared secret keys, certificates or username/password.
    
#### (+) "Pros"  
    + Very secure  
    + Very fast  
    + Open source design (Great Community Support)  
    + Supports Perfect Forward Secrecy
    + Supports a wide range of cryptographic algorithms
    + Can bypass firewalls easily
    
#### (-) "Cons"
    - Not supported completely on IOS
    - High Overhead / Latency
    - Proxy Problems
    - Complex
    - Third Party Software Required

- **Latest stabile release** ==> ***2.4.9 (16 April 2020)***

Usability | Configuration | Security | Future Development | Licence | Project Duration 
:---: | :---: | :---: | :---: | :---: | :---:
 9<sup>[1](#table)</sup> | 7<sup>[2](#table)</sup> | 8<sup>[3](#table)</sup> | Yes | GPL | 2001 --> 

---
    
## [WireGuard](https://www.wireguard.com/)  

- **General:**  
    - WireGuard® is an extremely simple yet fast and modern VPN that utilizes state-of-the-art cryptography.  
    - It aims to be faster, simpler, leaner, and more useful than IPsec, while avoiding the massive headache.  
    - It intends to be considerably more performant than OpenVPN.  
    - WireGuard is designed as a general purpose VPN for running on embedded interfaces and super computers alike, fit for many different circumstances.  
    - Initially released for the Linux kernel, it is now cross-platform (Windows, macOS, BSD, iOS, Android) and widely deployable.  
    - It is currently under heavy development, but already it might be regarded as the most secure, easiest to use, and simplest VPN solution in the industry.  
    

More info related to WireGuard can be found [HERE](https://www.the-digital-life.com/en/wireguard-vs-openvpn-and-ipsec-which-one-is-the-best/)

- **Security:**  
    - WireGuard utilizes the following:
        - Curve25519 for key exchange
        - ChaCha20 for encryption
        - Poly1305 for data authentication
        - SipHash for hashtable keys
        - BLAKE2s for hashing
        - UDP-based only.
    - Encryption:  
        - WireGuard only supports ChaCha20.  
        - Optional Pre-shared Symmetric Key Mode  
        - WireGuard supports Pre-shared Symmetric, which is included to mitigate any future advances in quantum computing.  
        - In the shorter term, if the pre-shared symmetric key is compromised, the Curve25519 keys still provide more than sufficient protection.  
    - Networking:  
        - WireGuard only works over UDP.  
        - WireGuard fully supports IPv6, both inside and outside of tunnel. It supports only layer 3 for both IPv4 and IPv6 and can encapsulate v4-in-v6 and vice versa.  
        - WireGuard supports multiple topologies:  
            - Point-to-point  
            - Star (Server/client)  
                - A client endpoint does not have to be defined before the client start sending data  
                - Client endpoints can be statically predefined.  
            - Mesh  
            - Since Point-to-point is supported, other topologies can be made, but not on the same tunnel.  


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

Usability | Configuration | Security | Future Development | Licence | Project Duration
:---: | :---: | :---: | :---: | :---: | :---:
 9<sup>[1](#table)</sup> | 3<sup>[2](#conf)</sup> | 9<sup>[3](#sec)</sup> | Yes | GPLv2 / Apache 2.0 | 2016 -->

---  

## [strongSwan](https://www.strongswan.org/)

- **General:**  
    - the OpenSource IPsec-based VPN Solution
    - strongSwan is a multiplatform IPsec implementation.
    - The focus of the project is on strong authentication mechanisms using X.509 public key certificates and optional secure storage of private keys and certificates on smartcards through a standardized PKCS#11 interface and on TPM 2.0.  
#### (+) “Pros”
    + Unlimited simultaneous connections
    + Unusual multihop and split-tunneling tools
    + Powerful IPSec policies
    + Well-designed app
    + supports IKEv1 and fully implements IKEv2
#### (-) “Cons”
    - Can be easily blocked
    - heavily relies on Linux kernel modules

Latest stabile release ==> v5.8.0 / May 20, 2019

Usability | Configuration | Security | Future Development | Licence | Project Duration
:---: | :---: | :---: | :---: | :---: | :---:
 9<sup>[1](#table)</sup> | 5<sup>[2](#conf)</sup> | 9<sup>[3](#sec)</sup> | Yes | GPLv2 | 2005 -->

- **Latest stabile release** ==> ***v5.8.0 / May 20, 2019***  

## [AlgoVPN](https://github.com/trailofbits/algo)  

- **General:**  
    - Algo VPN is a set of Ansible scripts that simplify the setup of a personal WireGuard and IPsec VPN.  
    - It uses the most secure defaults available and works with common cloud providers.  
    - Easy to deploy and distribute to the clients  
#### (+) “Pros”  
    + Supports only IKEv2
    + Supports only a single cipher suite w/ AES-GCM, SHA2 HMAC, and P-256 DH
    + Generates mobile config profiles to auto-configure Apple devices
    + Provides helper scripts to add and remove users
    + Blocks ads with a local DNS resolver and HTTP proxy
    + Based on current versions of Ubuntu and strongSwan
    + Installs to DigitalOcean, Amazon, Google, Azure or your own server
#### (-) “Cons”  
    - Does not support legacy cipher suites nor protocols like L2TP, IKEv1, or RSA
    - Does not install Tor, OpenVPN, or other risky servers
    - Does not depend on the security of TLS
    - Does not require client software on most platforms
    - Does not claim to provide anonymity or censorship avoidance
    - Does not claim to protect you from the FSB, MSS, DGSE, or FSM    

Usability | Configuration | Security | Future Development | Licence | Project Duration
:---: | :---: | :---: | :---: | :---: | :---:
 9<sup>[1](#table)</sup> | 3<sup>[2](#conf)</sup> | 9<sup>[3](#sec)</sup> | Yes | AGPL-3.0 License | 2012   -->


## [Citrix]()
- **General**
    - Citrix provides an all-in-one service as it is capable of handling the huge majority of things needed to create a fully working VPN.
    - Citrix also produces applications that run on top of the VPN to provide more advanced features. VPN, at its basest, is only capable of providing file sharing services.  
    - Citrix allows users from a remote location to run applications on the server and have access to resources as if they are located on the server itself.  
    - Citrix simplifies and unifies the deployment of applications for the whole company as only the server needs to be updated when adding or upgrading your software.  
    - In a standard VPN, you need to update each and every computer that uses the application.  


#### (+) “Pros”  
    + All in one solution
    + Support
#### (-) “Cons”  
    - Complicated 
    - expensive
    
## [Cisco Anyconnect](https://www.cisco.com/c/en/us/products/security/anyconnect-secure-mobility-client/index.html)
- **General:**
    - Very secure VPN from Cisco
    - The main benefits of Cisco AnyConnect are its protection for all devices, unimpeded access, proactive threat defense, robust network security, and one agent management.
    - Main features of Cisco AnyConnect are: Threat Defense, All-Around User Access, Single Agent Management, User & Endpoint Behavior Insights, Multiple Integrations


#### (+) “Pros”  
    + Fast
    + Secure
    + Easy to manage
    + Support
    + Granular integration
#### (-) “Cons”  
    - Harder to troubleshoot 
    - Expensive
    - Licensing
    - Connection dropping if the broadband/wifi isn't strong enough - tricky in some APAC countries 

## [Fortinet](https://www.fortinet.com/)
- **Greneral:**
    - Complete NGFW in relation what you pay.
    - Great VPN possibilities in regards of simplicity and security.
    - Integrated endpoint protection platform that provides automated next-generation threat protection, visibility and control of your software and hardware inventory across the entire security fabric.  
    - Identify & remediate vulnerable or compromised hosts across your attack surface.  
    - It Provides:  
        - Endpoint Visibility & Compliance throughout security fabric
        - Prevent Known Vulnerabilities from Being Exploited by Attackers
        - Automated behaviour based protection against unknown threats
        - Simplified Endpoint Management

#### (+) “Pros”  
    + Fast
    + Secure
    + Easy to manage
    + Support
    + Advanced troubleshooting
#### (-) “Cons”  
    - Kinda risky upgrades
    - Reporting could be better
    - Memory problems

Detailed product matrix can be found [HERE](https://www.fortinet.com/content/dam/fortinet/assets/data-sheets/Fortinet_Product_Matrix.pdf)



<a name="table">1</a>: Scale goes from ***0:*** **Not realy usefull** <--> ***10:*** **Totaly Usefull**  
<a name="conf">2</a>: How hard is to install it: Scale goes from ***0:*** **Kid could do it!** <--> ***10:*** **Extreamly Hard to install.**  
<a name="sec">3</a>: How good is the security: ***0:*** **meeeh** <--> ***10:*** **Rock solid..**  