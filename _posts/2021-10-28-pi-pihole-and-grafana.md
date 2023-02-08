---
title: Pi-Hole and Grafana Installation on Pi
tags: Pi
---

---

# ***Pi-hole***

## Install Pi-hole

```sh
# update your machine
sudo apt update && sudo apt upgrade
```

```sh
# run the script and follow the wizard
curl -sSL https://install.pi-hole.net | sudo bash
```

```sh
# after the installation you will be assigned admin pass which you can't change on GUI if you forget it
# so in the terminal, change the default password

pihole -a -p
[sudo] password for pi: 
Enter New Password (Blank for no password): 
Confirm Password: 
  [✓] New password set
```

- reference article [HERE](https://www.osradar.com/install-pihole-on-ubuntu-20-04/)

- access Pi-hole on "http://'your-pi-IP"

---
# Grafana

## Install Grafana

```sh
# add grafana keys
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

# add grafana repo
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

# system update & grafana install
sudo apt-get update; sudo apt-get install -y grafana

# enable and start grafana service
sudo /bin/systemctl enable grafana-server
sudo /bin/systemctl start grafana-server
```

- access Grafana on "http://'your-pi-IP:3000"

---
# Prometheus

## Install Pormetheus

- download the latest prometheus file from 

```sh
wget https://github.com/prometheus/prometheus/releases/download/v2.31.0-rc.0/prometheus-2.31.0-rc.0.linux-armv7.tar.gz
tar xfz prometheus-*
mv prometheus-* prometheus/
```

- access Prometheus on "http://'your-pi-IP:9090"

---
# ***speedtest for grafana***

## docker version speedtest

```sh
# make sure you have docker installed
sudo apt install docker docker-ce
```

- run docker container with

```sh
docker run -d \
  --name=speedtest-exporter \
  -p 9798:9798 \
  -e SPEEDTEST_PORT=<speedtest-port> #optional \
  -e SPEEDTEST_SERVER=<speedtest-serverid> #optional \
  --restart unless-stopped \
  miguelndecarvalho/speedtest-exporter
```

- clone the repo and go to the folder

```sh
git clone https://github.com/MiguelNdeCarvalho/speedtest-exporter.git && cd speedtest-exporter
```

- install dependencyes

```sh
pip3 install -r src/requirements.txt
```

- execute the exporter and access the site to see the metricks

```sh
python3 src/exporter.py

# access the site
http://localhost:9798/
```

- add exporter to Prometheus

```yaml
# my file looks like this [/home/pi/prometheus/prometheus.yml]

# my global config
global:
  scrape_interval: 15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
- job_name: "prometheus"
  static_configs:
    - targets: ["localhost:9090"]
- job_name: "speedtest-exporter"
  scrape_interval: 30m
  scrape_timeout: 1m
  static_configs:
    - targets: ["localhost:9798"]
```

- reference article [HERE](https://docs.miguelndecarvalho.pt/projects/speedtest-exporter/)