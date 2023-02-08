---
title: reverse proxy web caching
tags: Fortinet
---

# reverse proxy web caching  

- Example reverse proxy web caching and SSL offloading for an Internet web server using a static one-to-one virtual IP

---

- This section describes configuring SSL offloading for a reverse proxy web caching configuration using a static one-to-one firewall virtual IP (VIP). While the static one-to-one configuration described in this example is valid, its also common to change the destination port of the unencrypted HTTPS traffic to a commonly used HTTP port such as 8080 using a port forwarding virtual IP.

---

- **Network topology and assumptions**

  - In this configuration, clients on the Internet use HTTP and HTTPS to browse to a web server that is behind a FortiGate unit. A policy added to the FortiGate unit forwards the HTTP traffic to the web server. The policy also offloads HTTPS decryption and encryption from the web server so the web server only sees HTTP traffic.

  - The FortiGate unit also caches HTTP and HTTPS pages from the web server so when users access cached pages the web server does not see the traffic. Replies to HTTPS sessions are encrypted by the FortiGate unit before returning to the clients.

  - In this configuration, the FortiGate unit is operating as a web cache in reverse proxy mode. Reverse proxy caches can be placed directly in front of a web server. Web caching on the FortiGate unit reduces the number of requests that the web server must handle, therefore leaving it free to process new requests that it has not serviced before.

---

- **Using a reverse proxy configuration:**

  - avoids the capital expense of additional web servers by increasing the capacity of existing servers

  - serves more requests for static content from web servers

  - serves more requests for dynamic content from web servers

  - reduces operating expenses including the cost of bandwidth required to serve content

  - accelerates the response time of web servers and of page download times to end users.

  - When planning a reverse proxy implementation, the web server’s content should be written so that it is “cache aware” to take full advantage of the reverse proxy cache.

- In reverse proxy mode, the FortiGate unit functions more like a web server for clients on the Internet. Replicated content is delivered from the proxy cache to the external client without exposing the web server or the private network residing safely behind the firewall.

- In this example, the site URL translates to IP address 192.168.10.1, which is the port2 IP address of the FortiGate unit. The port2 interface is connected to the Internet.

- This example assumes that all HTTP traffic uses port 80 and all HTTPS traffic uses port 443.

- The FortiGate unit includes the web server CA and an SSL server configuration for IP address 172.10.20.30 and port to 443. The name of the file containing the CA is Rev_Proxy_Cert_1.crt.

- The destination address of incoming HTTP and HTTPS sessions is translated to the IP address of the web server using a static one-to-one virtual IP that performs destination address translation (DNAT) for the HTTP packets. The DNAT translates the destination address of the packets from 192.168.10.1 to 172.10.20.30 but does not change the destination port number.

- When the SSL server on the FortiGate unit decrypts the HTTPS packets their destination port is changed to port 80.

- Reverse proxy web caching and SSL offloading for an Internet web server using static one-to-one virtual IPs

---

### General configuration steps

- This section breaks down the configuration for this example into smaller procedures. For best results, follow the procedures in the order given:

1. Configure the FortiGate unit as a reverse proxy web cache server.

2. Configure the FortiGate unit for SSL offloading of HTTPS traffic.

3. Add an SSL server to offload SSL encryption and decryption for the web server.

- Also note that if you perform any additional actions between procedures, your configuration may have different results.

### Configuration steps – web-based manager

- To configure the FortiGate unit as a reverse proxy web cache server

1. Go to Policy & Objects > Virtual IPs and select Create New to add a static NAT virtual IP that translates destination IP addresses from 192.168.10.1 to 172.10.20.30 (and does not translate destination ports):

---

| VIP Type | IPv4 VIP |  
| Name | Reverse_proxy_VIP |  
| Interface | port2 |  
| Type | Static NAT |  
| Source Address Filter | Do not select |  
| External IP Address/Range | 192.168.10.1 |  
| Mapped IP Address/Range | 172.10.20.30 |  
| Port Forwarding | Do not select |  

---

1. Select OK.
2. Go to Policy & Objects > IPv4 Policy and select Create New to add a port2 to port1 security policy that accepts HTTP and HTTPS traffic from the Internet.

- Do not select security profiles.

3. Set the destination address to the virtual IP. You do not have to enable NAT.

|Incoming Interface | port2 |  
|Source Address | all |  
| Outgoing Interface | port1 |  
| Destination Address | Reverse_proxy_VIP |  
| Schedule | always |  
| Service | HTTP HTTPS |  
| Action | ACCEPT |  

4. Turn on Web Cache.
5. Select OK.
6. From the CLI enter the following command to add HTTPS web caching to the security policy

- Assume the index number of the policy is 5.

```bash
config firewall policy edit 5
set webcache-https ssl-server end
```

- To configure the FortiGate unit to offload SSL encryption and cache HTTPS content

1. Go to System > Certificates and select Import to import the web server’s CA.

- For Type, select Local Certificate. Select the Browse button to locate the file (example file name: Rev_Proxy_ Cert_1.crt).
- The certificate key size must be 1024 or 2048 bits. 4096-bit keys are not supported.

2. Select OK to import the certificate.
3. From the CLI, enter the following command to add the SSL server and to add the server’s certificate to the SSL server.

- The SSL server ip must match the destination address of the SSL traffic after being translated by the virtual IP (172.10.20.30) and the SSL server port must match the destination port of the SSL traffic (443). The SSL server operates in half mode since it performs a single-step conversion (HTTPS to HTTP or HTTP to HTTPS).

```bash
config wanopt ssl-server edit rev_proxy_server set ip 172.10.20.30
set port 443
set ssl-mode half
set ssl-cert Rev_Proxy_Cert_1
end
```

### Configuration steps – CLI

- To configure the FortiGate unit as a reverse proxy web cache server

1. Enter the following command to add a static NAT virtual IP that translates destination IP addresses from

- 192.168.10.1 to 172.10.20.30 (and does not translate destination ports):

```bash
config firewall vip
edit Reverse_proxy_VIP set extintf port2 set type static-nat
set extip 192.168.10.1
set mappedip 172.10.20.30 end
```

2. Enter the following command to add a port2 to port1 security policy that accepts HTTP and HTTPS traffic from the

- Internet. Enable web caching and HTTPS web caching.
- Do not select security profiles. Set the destination address to the virtual IP. You do not have to enable NAT.

```bash
config firewall policy edit 0
set srcintf port2 set srcaddr all set dstintf port1
set dstaddr Reverse_proxy_VIP
set schedule always
set service HTTP HTTPS
set action accept set webcache enable
set webcache-https ssl-server end
```

- To add an SSL server to offload SSL encryption and decryption for the web server

1. Place a copy of the web server’s CA (file name Rev_Proxy_Cert_1.crt) in the root folder of a TFTP server.

2. Enter the following command to import the web server’s CA from a TFTP server. The IP address of the TFTP server is 10.31.101.30:

```bash
execute vpn certificate local import tftp Rev_Proxy_Cert_1.crt 10.31.101.30
```

- The certificate key size must be 1024 or 2048 bits. 4096-bit keys are not supported.

3. From the CLI, enter the following command to add the SSL server.

- The SSL server ip must match the destination address of the SSL traffic after being translated by the virtual IP (172.10.20.30) and the SSL server port must match the destination port of the SSL traffic (443). The SSL server operates in half mode since it performs a single-step conversion (HTTPS to HTTP or HTTP to HTTPS).

```bash
config wanopt ssl-server edit rev_proxy_server set ip 172.10.20.30
set port 443
set ssl-mode half
set ssl-cert Rev_Proxy_Cert_1 end
```

4. Configure other ssl-server settings that you may require for your configuration.
