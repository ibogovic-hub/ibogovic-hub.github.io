```bash
#!/bin/bash

diff -q /srv/tftp/test.conf /srv/tftp/check.conf 1>/dev/null
if [[ $? == "0" ]]
then
  echo "Configuration OK" >> /home/<user>/logs/show-ver.log
else
  echo "Configuration changes" >> /home/<user>/logs/show-ver.log
fi
```