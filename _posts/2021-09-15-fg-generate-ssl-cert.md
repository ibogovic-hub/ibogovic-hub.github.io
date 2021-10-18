---
title: Generate SSL Certificate
tags: Fortinet
---

> How to generate certificates using OpenSSL

More information on OpenSSL can be found at this website:
[OpenSSL](https://www.openssl.org)

The FortiGate cookbook article '[SSL VPN with certificate authentication](https://docs.fortinet.com/document/fortigate/latest/administration-guide/266506/ssl-vpn-with-certificate-authentication)' requires three certificates:
- CA certificate.
- server certificate (signed by the CA certificate).
- user certificate (signed by the CA certificate).

These can be generated using OpenSSL as follows:

1. Generate the CA:
```sh
openssl genrsa -aes256 -out ca-key.pem 4096
openssl req -x509 -new -nodes -extensions v3_ca -key ca-key.pem -days 365 -out ca-root.pem -sha512
# This creates two files: the CA file 'ca.pem' and its private key 'privkey.pem' - a password for the private key is required.
```
2. Create a serial file:
```sh
echo 00 > serial.srl
```
3. Generate the server certificate and key:
```sh
openssl genrsa -out server.key 4096
openssl req -key server.key -new -out server.req
openssl x509 -req -in server.req -CA ca-root.pem -CAkey ca-key.pem -CAserial serial.srl -out server.pem
```
4. Generate the client certificate and key:
```sh
openssl genrsa -out user.key 4096
openssl req -key user.key -new -out user.req
openssl x509 -req -in user.req -CA ca-root.pem -CAkey ca-key.pem -CAserial serial.srl -out user.pem
```  

5. Merge the client certificate and key into a PFX file:
```sh
openssl pkcs12 -export -out user.pfx -inkey user.key -in user.pem
# It is possible now to proceed with the Cookbook article
```
- The three certificates to use are: ***ca-root.pem, server.pem, and user.pfx***

