# Blocky installer

## What is Blocky

Blocky is a DNS proxy and ad-blocker for the local network written in Go.

Official repository:
* https://github.com/0xERR0R/blocky.git
* Official [installation](https://0xerr0r.github.io/blocky/installation/) manual

## Installer features

`installer.sh` it is a bash script for install [Blocky](https://github.com/0xERR0R/blocky.git) to:

* CentOS/Fedora Linux
* Blocky is installed as systemctl unit service to `/opt/blocky` catalog as default. 
* After install Blocky works from regular user.

_Note: All features tested. deployed and using on CentOS 8_

## Features

* Install from scratch to rpm based distros
  * Steb-by-step installer
  * Automate installer
* Detect and download latest `blocky` release from official repo
* Install under simple user
  * New user creation
  * Allow to user using privileged ports (aka 53) without sudo
  * Allow to user start, stop, enable, disable `blocky` service
  * Create `systemctl` unit service
  * Generate simple `config.yml`
* Reinstall `blocky`
* Backup `blocky`
* Install additional software (optionally):
  * Cloudflared
  * Cerbot
  * Nginx

## Sync configs

After install Blocky you can use sync feature to download or upload config to remote server over ssh connection with `sync.sh`.

In first run `sync.sh` will ask:
* Remote server IP
* Remote server port
* Remote server ssh user name

Then will try copy ssh key to remote server with `ssh-copy-id`, after that you can run script again and `sync.sh` will copy `cinfig.yml` from remote server to local `/opt/blocky` folder.

You can also configure the scheduler with crontab (as example):
```bash
*/30 * * * * /bin/bash /home/blockyusr/sync.sh
```

## Install Prometheus Stack

Additionally you can install Prometheus stack to you own CentOS 8 server:

* Prometheus
* Node Exporter
* Grafana

See more info on this repository:
* https://github.com/m0zgen/install-prometheus-stack 

### TODO's
# TODO add diff compare procedure fro syncing