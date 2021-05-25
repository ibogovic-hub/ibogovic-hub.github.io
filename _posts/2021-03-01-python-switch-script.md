---
title: python switch config
layout: article
tags: Python
article_header:
  type: cover
---

## Python script for automatic switch configuration

- idea behind this script is to automatically reconfigure network switch "in case of..."  
this script is looking for new IP received from DHCP server with specific parameters defined.  
more detailed description below.

- all things currently configured in this script is prone to changes.  

## script description  

- **first part of the script is to define where log file is placed, format of the log and date:**  

```py
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Check IP Address
"""

__author__ = 'Ivan Bogovic'
__copyright = 'Copyright 2020, hmmmm'

import logging
import subprocess
import datetime

x = datetime.datetime.now()
logging.basicConfig(filename = '/home/<user>/Documents/logs/python.log', format = '%(asctime)s  %(levelname)-10s %(processName)s  %(name)s %(message)s', datefmt =  "%Y-%m-%d-%H-%M-%S")

```  

- **next section is opening DHCPD log file and searching for (from the bottom up):**  

1. DHCPACK - confirmation that IP address is assigned to the device
2. Switch - parameter that combines word from 1 point and contains ***"Switch"***
3. when both criteria are met then it extracts characters starting 11 "palaces" till first empty sign (space).
4. in our case it is IP address assigned to newly connected switch and saves the result in variable.  

```py
ip_data = ""
try:
f = open('/var/log/dhcpd.log', 'r')
content = f.read()
offset = content.rfind('DHCPACK')
if offset >= 0:
offset2 = content.find('Switch', offset)
if offset2 >= 0:
space = content.find(' ', offset + 11)
ip_data = content[offset+11:space]
print(ip_data)
f.close()
except:
logging.debug('Error: Could not read IP')
```  

- **this section runs the first "except script" [show-ver.sh](/assets/scripts/show-ver.sh) that checks hardware version of the switch**  

```py
if len(ip_data) > 8:
subprocess.call(["/home/<user>/scripts/show-ver.sh",ip_data])
```  

- **this part is taking the result of the script in previous step and checking some requirements**  

1. searching for the line containing word ***"flash"***  
2. when **"flash"** is found, then it looks for the part containing ***"FSOS-S5850"*** (switch type).
3. if both criteria are met then it takes the part of the line containing only switch type - in this case = ***"S5850"***  

```py
try:
f = open("/home/<user>/Documents/logs/show-ver.log", "r")
content = f.read()
offset = content.rfind('flash')
if offset >= 0:
offset2 = content.find('FSOS-S5850', offset)
if offset2 >= 0:
space = content.find("-and", offset + 12)
S5850 = content[offset+17:space]
print(S5850)

except:
logging.debug('Error: no new')
```  

- **currently the last part of the script is pushing "except script" [fs-s5850.sh] to reconfigure the switch** if all upper criteria is met.  

```python
if S5850 == "S5850":
error = subprocess.call(["/home/<user>/scripts/fs-s5850.sh",ip_data])
if(error):
logging.warning('Error: no go for S5850')
f.close()
```
