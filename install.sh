#!/bin/bash
# Install Blocky on to CentOS, Fedora, Debian, Ubuntu Linux

set -e

# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Vars
# ---------------------------------------------------\
_APP_NAME="blocky"
_APP_USER_NAME="blockyusr"
_DESTINATION=/opt/${_APP_NAME}
_BINARY=`curl -s https://api.github.com/repos/0xERR0R/blocky/releases/latest | grep browser_download_url | grep "Linux_x86_64" | awk '{print $2}' | tr -d '\"'`

SERVER_IP=$(hostname -I | cut -d' ' -f1)
SERVER_NAME=$(hostname)
SYSTEMD_UNIT=/etc/systemd/system/$_APP_NAME.service
RESTARTER=/usr/local/sbin/restart-blocky.sh
START_DATE=`date '+%d-%m-%Y_%H-%M-%S'`
backup_folder=/opt/blocky_backup_$START_DATE

# Output messages
# ---------------------------------------------------\

# And colors
RED='\033[0;91m'
GREEN='\033[0;92m'
CYAN='\033[0;96m'
YELLOW='\033[0;93m'
PURPLE='\033[0;95m'
BLUE='\033[0;94m'
BOLD='\033[1m'
WHiTE="\e[1;37m"
NC='\033[0m'

ON_SUCCESS="DONE"
ON_FAIL="FAIL"
ON_ERROR="Oops"
ON_CHECK="✓"

Info() {
  echo -en "[${1}] ${GREEN}${2}${NC}\n"
}

Warn() {
  echo -en "[${1}] ${PURPLE}${2}${NC}\n"
}

Success() {
  echo -en "[${1}] ${GREEN}${2}${NC}\n"
}

Error () {
  echo -en "[${1}] ${RED}${2}${NC}\n"
}

Splash() {
  echo -en "${WHiTE} ${1}${NC}\n"
}

space() { 
  echo -e ""
}

# Set params and usage
# ---------------------------------------------------\

splash() {
  echo "

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
_/                                                              _/
_/                                                              _/
_/       _/        _/                      _/                   _/
_/      _/_/_/    _/    _/_/      _/_/_/  _/  _/    _/    _/    _/
_/     _/    _/  _/  _/    _/  _/        _/_/      _/    _/     _/
_/    _/    _/  _/  _/    _/  _/        _/  _/    _/    _/      _/
_/   _/_/_/    _/    _/_/      _/_/_/  _/    _/    _/_/_/       _/
_/                                                    _/        _/
_/                                               _/_/           _/
_/                                                              _/
_/                                                              _/
_/  Blocky Installer. Version: 1.4                              _/
_/                                                              _/
_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  "
}

# Help information
usage() {

  Info "Usage" "You can use this script with several parameters:"
  Info "$ON_CHECK" "./install.sh -e : export configs"
  Info "$ON_CHECK" "./install.sh -a : Auto-install all software"
  Info "$ON_CHECK" "./install.sh -r : Restore permissions to Blocky catalog"
  Info "$ON_CHECK" "./install.sh -b : Backup existing Blocky installation"
  Info "$ON_CHECK" "./install.sh -c : Check existing Blocky"
  Info "$ON_CHECK" "./install.sh -u : Uninstall Blocky"
  exit 1

}

# Checks arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
      -e|--export) _EXPORT=1; ;;
      -a|--auto) _AUTO=1; ;;
      -f|--full) _FULL=1; ;;
      -r|--restore-permission) _RESTORE_PERMISSIONS=1; ;;
      -b|--backup) _BACKUP=1; ;;
      -c|--check) _CHECK=1; ;;
      -u|--uninstall) _UNINSTALL=1; ;;
      -h|--help) usage ;;
      *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Functions
# ---------------------------------------------------\

# Yes / No confirmation
confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

# Check is current user is root
isRoot() {
  if [ $(id -u) -ne 0 ]; then
    Error $ON_ERROR "You must be root user to continue"
    exit 1
  fi
  RID=$(id -u root 2>/dev/null)
  if [ $? -ne 0 ]; then
    Error "User root no found. You should create it to continue"
    exit 1
  fi
  if [ $RID -ne 0 ]; then
    Error "User root UID not equals 0. User root must have UID 0"
    exit 1
  fi
}

# SELinux status
isSELinux() {
  if [[ "$RPM" -eq "1" ]]; then
    selinuxenabled
    if [ $? -ne 0 ]
    then
        Error "SELinux:\t\t" "DISABLED"
    else
        Info "SELinux:\t\t" "ENABLED"
    fi
  fi
}

# Checks supporting distros
checkDistro() {
  # Checking distro
  if [ -e /etc/centos-release ]; then
      DISTRO=`cat /etc/redhat-release | awk '{print $1,$4}'`
      RPM=1
  elif [ -e /etc/fedora-release ]; then
      DISTRO=`cat /etc/fedora-release | awk '{print ($1,$3~/^[0-9]/?$3:$4)}'`
      RPM=2
  elif [ -e /etc/os-release ]; then
    DISTRO=`lsb_release -d | awk -F"\t" '{print $2}'`
    RPM=0
    DEB=1
  else
      Error "Your distribution is not supported (yet)"
      exit 1
  fi
}

# Checking dirs
is_directory()
{
    if [ -d "${1}" ]; then
        true; return
    else
        false; return
    fi
}

# Checking files
is_file()
{
    if [ -f "${1}" ]; then
        true; return
    else
        false; return
    fi
}

# get Actual date
getDate() {
  date '+%d-%m-%Y_%H-%M-%S'
}
# backup_folder=/opt/blocky_backup_$(getDate)

disable_resolved_unit() {
  # is systemd-resolved already exist
  if (systemctl is-active --quiet systemd-resolved); then
    systemctl disable --now systemd-resolved.service
  fi
}

enable_resolved_unit() {
  if systemctl cat systemd-resolved >/dev/null 2>&1; then
      systemctl enable --now systemd-resolved.service
  fi
}

# Install core packages
rpm_installs() {
  yum install wget net-tools git yum-utils tar rsync -y -q -e 0
}

apt_installs() {
  apt -y install wget net-tools git tar rsync curl
}

# Set permissions to destibation folder
set_permissions() {
  Info "$ON_CHECK" "Set user $_APP_USER_NAME permissions to $_DESTINATION catalog"
  chown -R $_APP_USER_NAME:$_APP_USER_NAME $_DESTINATION
  setcap cap_net_bind_service=ep $_DESTINATION/blocky
}

# Create simple user for blocky
create_APP_USER_NAME() {
  if [[ $(getent passwd $_APP_USER_NAME) = "" ]]; then
    useradd -m $_APP_USER_NAME
    Info "$ON_CHECK" "User $_APP_USER_NAME is created"

    # Generate ssh key for sync configs between servers
    echo "%$_APP_USER_NAME ALL=(ALL) NOPASSWD:/bin/systemctl restart $_APP_NAME,/bin/systemctl stop $_APP_NAME,/bin/systemctl start $_APP_NAME,/bin/systemctl status $_APP_NAME" > /etc/sudoers.d/blockyusr
    su - $_APP_USER_NAME -c "yes ~/.ssh/id_rsa | ssh-keygen -q -t rsa -N '' >/dev/null"

    # Add sync.sh to user home folder (deprecated)
    # rsync -av $SCRIPT_PATH/utils/sync.sh /home/$_APP_USER_NAME/

    # Set permissions for $_APP_USER_NAME to $_DESTINATION folder
    set_permissions
  else
    Info "$ON_CHECK" "User $_APP_USER_NAME is exist"
    Info "$ON_CHECK" "Rebuild permissions"
    set_permissions
  fi
}

# Create basic blocky config.yml
create_blocky_config() {
# Config
# https://github.com/0xERR0R/blocky/blob/development/docs/installation.md
cat > $_DESTINATION/config.yml <<_EOF_
upstream:
  default:
    - 1.1.1.1
    - 8.8.8.8
blocking:
  blackLists:
    ads:
      - https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
      - https://raw.githubusercontent.com/m0zgen/dns-hole/master/dns-blacklist.txt
      - https://raw.githubusercontent.com/m0zgen/dns-hole/master/malisious.txt
  whiteLists:
    ads:
      - https://raw.githubusercontent.com/m0zgen/dns-hole/master/whitelist.txt
      - https://raw.githubusercontent.com/m0zgen/dns-hole/master/vendors-wl/microsoft.txt
      - https://raw.githubusercontent.com/m0zgen/dns-hole/master/vendors-wl/google.txt
      - https://raw.githubusercontent.com/m0zgen/dns-hole/master/regex/common-wl.txt
  clientGroupsBlock:
    default:
      - ads
port: 53
httpPort: 4000
bootstrapDns: 1.1.1.1
_EOF_
}

# Create restarter script
create_restarter_script() {
# Config
# https://github.com/0xERR0R/blocky/blob/development/docs/installation.md
cat > $RESTARTER <<_EOF_
#!/bin/bash
# Sys env / paths / etc
# -------------------------------------------------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

chown -R blockyusr:blockyusr /opt/blocky/
systemctl stop blocky
sleep 3
setcap cap_net_bind_service=ep /opt/blocky/blocky
systemctl start blocky
_EOF_

chmod +x $RESTARTER
}

# Create systemd unit
create_systemd_config() {
# Systemd unit
cat > $SYSTEMD_UNIT <<_EOF_
[Unit]
Description=Blocky is a DNS proxy and ad-blocker
ConditionPathExists=${_DESTINATION}
After=local-fs.target

[Service]
User=${_APP_USER_NAME}
Group=${_APP_USER_NAME}
Type=simple
WorkingDirectory=${_DESTINATION}
ExecStart=${_DESTINATION}/blocky --config ${_DESTINATION}/config.yml
Restart=on-failure
RestartSec=10

StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=blocky

[Install]
WantedBy=multi-user.target
_EOF_

systemctl daemon-reload
create_restarter_script
systemctl enable $_APP_NAME
disable_resolved_unit
Info "${GREEN}✓${NC}" "Restarting..."
$RESTARTER

# if [[ ! -f "$SYSTEMD_UNIT" ]]; then
#   systemctl enable --now $_APP_NAME >/dev/null 2>&1
#   Info "${GREEN}✓${NC}" "Blocky enabled as unit service by name - $_APP_NAME"
# else
#   Info "${GREEN}✓${NC}" "Blocky unit is exist - $SYSTEMD_UNIT"
#   Info "${GREEN}✓${NC}" "Restarting..."
#   create_restarter_script
#   $RESTARTER
# fi

sleep 2

if (systemctl is-active --quiet $_APP_NAME); then
    echo -e "[${GREEN}✓${NC}] Blocky is running"
else
  echo -e "[${RED}✓${NC}] Blocky does not started, please check service status with command: journalctl -xe"
fi

}

# Checking installed software and them install
check_software() {
  echo -e "[${GREEN}✓${NC}] Install $1"

  if [[ "$_AUTO" -eq "1" ]]; then
      if ! type "$1" >/dev/null 2>&1; then
            git clone --depth=1 https://github.com/m0zgen/$2.git $_DESTINATION/$2
            $_DESTINATION/$2/install.sh
          else
            Info "$ON_CHECK" "$1 already installed"
          fi
  else
    if confirm "Install $1? (y/n or enter)"; then

        if ! type "$1" >/dev/null 2>&1; then
          git clone --depth=1 https://github.com/m0zgen/$2.git $_DESTINATION/$2
          $_DESTINATION/$2/install.sh
        else
          Info "$ON_CHECK" "$1 already installed"
        fi

      fi
  fi

}

# Install Cloudflared, Certbot, Nginx
install_additional_software() {

  if [[ "$RPM" -eq "1" ]] || [[ "$RPM" -eq "2" ]]; then
    check_software "cloudflared" "install-cloudflared"
    check_software "certbot" "install-certbot"
    check_software "nginx" "install-nginx"
  fi

  # Read permission for regular users
  # chmod -R 755 /etc/letsencrypt/live/
  # chmod -R 755 /etc/letsencrypt/archive/

}

backup_blocky() {

    if is_directory "/opt/blocky"; then
      # local backup_folder=/opt/blocky_backup_$(getDate)

      Info "$ON_CHECK" "Blocky will be backup to: $backup_folder"

      mkdir -p $backup_folder
      cp -r $_DESTINATION $backup_folder/

      if is_directory "/etc/nginx"; then
        cp /etc/nginx/nginx.conf $backup_folder/
        cp -r /etc/nginx/conf.d $backup_folder/
      fi

      Info "$ON_CHECK" "Done!"
    else
      Warn "$ON_ERROR" "Blocky does not found. Exit. Bye."
      exit 1
    fi
    
}

# Download latest blocky release from official repo
download_blocky_auto() {

  # Check destination folder
  if [[ ! -f $_DESTINATION/blocky ]]; then
    mkdir -p $_DESTINATION/logs
    cd $_DESTINATION

    wget -q "$_BINARY"
    tar xf `ls *.tar.gz`

  else
    Warn "$ON_CHECK" "Catalog $_DESTINATION exist! Blocky already installed?"

    if (systemctl is-active --quiet $_APP_NAME); then
      systemctl stop $_APP_NAME
      sleep 2
      enable_resolved_unit
    fi

    backup_blocky

    mkdir -p $_DESTINATION/logs
    cd $_DESTINATION

    Info "${GREEN}✓${NC}" "Download blocky.."
    wget -q "$_BINARY"

    Info "${GREEN}✓${NC}" "Unpacking blocky.."
    tar xf `ls *.tar.gz`

    Info "${GREEN}✓${NC}" "Restore blocky config.."
    cp $backup_folder/blocky/config.yml $_DESTINATION/

    Info "${GREEN}✓${NC}" "Update blocky systemd config.."
    create_systemd_config
    create_restarter_script

    # DONE - Checks user already exists

    Info "${GREEN}✓${NC}" "Restarting blocky.."
    disable_resolved_unit
    sleep 2
    $RESTARTER
    
    if [[ "$_FULL" -eq "1" ]]; then
      echo "Full stack install"
      install_additional_software
    fi

    Info "${GREEN}✓${NC}" "Blocky reinstalled"
    Info "${GREEN}✓${NC}" "Done!"
    exit 1
  fi
}

download_blocky() {

  Info "$ON_CHECK" "Run Blocky installer"
  # Check destination folder
  if [[ ! -f $_DESTINATION/blocky ]]; then

   Info "$ON_CHECK" "Download latest Blocky relese..."
   Info "$ON_CHECK" "Source: $_BINARY"
   Info "$ON_CHECK" "Destination: $_DESTINATION"

    mkdir -p $_DESTINATION/logs
    cd $_DESTINATION
    
    wget -q "$_BINARY"
    tar xf `ls *.tar.gz`
    
  else

    Warn "$ON_CHECK" "Catalog $_DESTINATION exist! Blocky already installed?"

    if confirm " $ON_CHECK Reinstall Blocky? (y/n or enter)"; then

      if (systemctl is-active --quiet $_APP_NAME); then
        systemctl stop $_APP_NAME
        enable_resolved_unit
        sleep 2
      fi

      # local backup_folder=/opt/blocky_backup_$(getDate)
      mkdir -p $backup_folder
      mv $_DESTINATION $backup_folder
      
      mkdir -p $_DESTINATION/logs
      cd $_DESTINATION

      Info "${GREEN}✓${NC}" "Download blocky.."
      wget -q "$_BINARY"

      Info "${GREEN}✓${NC}" "Unpacking blocky.."
      tar xf `ls *.tar.gz`
      
      Info "${GREEN}✓${NC}" "Restore blocky config.."
      cp $backup_folder/blocky/config.yml $_DESTINATION/

      Info "${GREEN}✓${NC}" "Update blocky systemd config.."
      create_systemd_config

      # TODO - Checks user already exists

      Info "${GREEN}✓${NC}" "Restarting blocky.."
      disable_resolved_unit
      create_restarter_script
      $RESTARTER


      if confirm " $ON_CHECK Install additional software? (y/n or enter)"; then
          install_additional_software
      else
        Info "${GREEN}✓${NC}" "Blocky reinstalled. Bye.."
        exit 1
      fi


      Info "${GREEN}✓${NC}" "Done!"

      exit 1
    else
      Info "${GREEN}✓${NC}" "Reinstall declined. Please check $_DESTINATION catalog. Bye.."
      exit 1
    fi
  fi
}

check_53() {
  # netstat -pnltu | grep -w :53 | grep -i listen | awk '{print $7}'
  if ss -tulpn | grep ':53' >/dev/null; then
    Error "$ON_CHECK" "Another DNS is running on 53 port!"
    PORT_USING=`ss -tulpn | grep ':53' | grep -i listen | awk '{print $7}'`
    Info "$ON_CHECK" "Port using by - $PORT_USING"

    if (systemctl is-active --quiet systemd-resolved); then
          Warn "$ON_CHECK" "Systemd-resolve possible using port"

          if confirm " $ON_CHECK Disable? (y/n or enter for skip)"; then
              disable_resolved_unit
          else
            Info "${GREEN}$ON_CHECK${NC}" "Blocky already installed to $_DESTINATION."
            exit 1
          fi
    fi

    if confirm " $ON_CHECK Continue? (y/n or enter)"; then
      Info "$ON_CHECK" "Run Blocky installer"

      if (systemctl is-active --quiet systemd-resolved); then
        if confirm " $ON_CHECK Disable systemd-resolved? (y/n or enter)"; then
          systemctl disable --now systemd-resolved >/dev/null 2>&1
          Info "$ON_CHECK" "Systemd-resolved disabled"
        fi
      fi
    else
      enable_resolved_unit
      echo -e "[${RED}✓${NC}] Blocky installer exit. Bye."
      exit 1
    fi

  fi
}

set_hostname() {
  read -p "Setup new host name: " answer
  hostnamectl set-hostname $answer
}

self_checking() {

  if [[ $(getent passwd $_APP_USER_NAME) = "" ]]; then
    Error "$ON_CHECK" "User $_APP_USER_NAME does not exist"
  else
    Info "$ON_CHECK" "User $_APP_USER_NAME is exist"
  fi

  if (systemctl is-active --quiet $_APP_NAME); then
    Info "$ON_CHECK" "Service $_APP_NAME is running"
  else
    Error "$ON_CHECK" "Service $_APP_NAME does not running"
  fi

  if is_file $RESTARTER; then
    Info "$ON_CHECK" "You can restart blocky service with $RESTARTER script"
  else
    Error "$ON_CHECK" "Restarter script $RESTARTER does not found"
  fi

}

export_configs() {

  cd /opt

  if [[ -d /etc/nginx ]]; then
    tar -zcvf blocky_$SERVER_NAME_$START_DATE.tar.gz $_DESTINATION /etc/nginx
  else
    tar -zcvf blocky_$SERVER_NAME_$START_DATE.tar.gz $_DESTINATION
  fi
  mv blocky_$SERVER_NAME_$START_DATE.tar.gz ~/
  Info "$ON_CHECK" "Archive saved to: ~/"
}

# Uninstall blocky
# ---------------------------------------------------\

uninstall_blocky() {

  Info "$ON_CHECK" "Blocky uninstaller is starting..."
  if confirm " $ON_CHECK Uninstall blocky (will be remove all configs and etc)? (y/n or enter)"; then

    Info "$ON_CHECK" "Checking existing installation..."

    if is_directory "/opt/blocky"; then

      Warn "$ON_CHECK" "Blocky found. Uninstall..."

      if is_file "/etc/systemd/system/blocky.service"; then
        Info "$ON_CHECK" "Disable Blocky service"
        systemctl disable --now blocky.service
        rm -rf /etc/systemd/system/blocky.service
      fi

      if is_file $RESTARTER; then
        rm -rf $RESTARTER
      fi
      
      rm -rf /opt/blocky
      rm -rf /usr/local/sbin/restart-bld.sh

      if [[ "$RPM" -eq "1" ]] || [[ "$RPM" -eq "2" ]]; then
          if is_directory "/home/$_APP_USER_NAME"; then
            # Delete with SELinux context
            userdel -r -f -Z $_APP_USER_NAME
          fi
        else
          if is_directory "/home/$_APP_USER_NAME"; then
            userdel -r -f $_APP_USER_NAME
          fi
      fi

      

      if is_directory "/etc/cloudflared"; then
        if confirm " $ON_CHECK Uninstall Cloudflared (will be remove all configs and etc)? (y/n or enter)"; then
          systemctl disable --now cloudflared.service
          yum erase cloudflared -y
          rm -rf /etc/cloudflared
        fi
      fi

      if is_directory "/etc/nginx"; then
        
        if confirm " $ON_CHECK Uninstall nginx (will be remove all configs and etc)? (y/n or enter)"; then
            systemctl disable --now nginx.service
            yum erase nginx -y
            rm -rf /opt/nginx
        fi

      fi

      enable_resolved_unit

    else
      Warn "$ON_CHECK" "Blocky does not found on this computer. Exit."
      exit 1
    fi

  else
    Info "$ON_CHECK" "Ok. Exit. Bye..."
    exit 1
  fi
}

# Install blocky
# ---------------------------------------------------\

# Checking privileges ans supported platform
splash
isRoot
checkDistro

space


init_auto() {
  Info "$ON_CHECK" "Blocky installer is starting..."

  Info "$ON_CHECK" "Run RPM installer..."
  
  if [[ "$RPM" -eq "1" ]]; then
    echo -e "[${GREEN}✓${NC}] Install CentOS packages"
    rpm_installs
  fi

  if [[ "$RPM" -eq "2" ]]; then
    echo -e "[${GREEN}✓${NC}] Install Fedora packages"
    rpm_installs
  fi

  if [[ "$DEB" -eq "1" ]]; then
    echo -e "[${GREEN}✓${NC}] Install Debian packages"
    apt_installs
  fi

  download_blocky_auto
  create_blocky_config
  create_APP_USER_NAME
  check_53
  create_systemd_config
  create_restarter_script

  if [[ "$_FULL" -eq "1" ]]; then
      echo "Full stack install"
      install_additional_software
  fi

  Info "${GREEN}$ON_CHECK${NC}" "Blocky installed to $_DESTINATION. Bye.."
  self_checking
}

rpm_actions() {
  rpm_installs
  download_blocky
  create_blocky_config
  create_APP_USER_NAME
  check_53
  create_systemd_config
  create_restarter_script

  if confirm " $ON_CHECK Install additional software? (y/n or enter)"; then
    install_additional_software
  else
    self_checking
    Info "${GREEN}$ON_CHECK${NC}" "Blocky installed to $_DESTINATION. Bye.."
    exit 1
  fi
}

apt_actions() {
  apt_installs
  download_blocky
  create_blocky_config
  create_APP_USER_NAME
  check_53
  create_systemd_config
  create_restarter_script
}

init() {
  
  Info "$ON_CHECK" "Blocky installer is starting..."
  if confirm " $ON_CHECK Install blocky? (y/n or enter)"; then

      if confirm " $ON_CHECK Set hostname? (y/n or enter)"; then
        set_hostname
      fi

      if [[ "$RPM" -eq "1" ]]; then
        Info "$ON_CHECK" "Run CentOS installer..."
        echo -e "[${GREEN}✓${NC}] Install CentOS packages"
        rpm_actions
      fi

      if [[ "$RPM" -eq "2" ]]; then
        Info "$ON_CHECK" "Run Fedora installer..."
        echo -e "[${GREEN}✓${NC}] Install Fedora packages"
        rpm_actions
      fi

      if [[ "$DEB" -eq "1" ]]; then
        Info "$ON_CHECK" "Run Debian installer..."
        echo -e "[${GREEN}✓${NC}] Install Debian packages"
        apt_actions
      fi

      self_checking

  else
    Info "${GREEN}$ON_CHECK${NC}" "Bye.."
    exit 1
  fi
}

# Inits
# ---------------------------------------------------\

# splash

if [[ "$_EXPORT" -eq "1" ]]; then
    echo "Export configs!"
    export_configs
elif [[ "$_AUTO" -eq "1" ]]; then
  echo "Auto install"
  init_auto
elif [[ "$_RESTORE_PERMISSIONS" -eq "1" ]]; then
    echo "Restore permissions"
    set_permissions
elif [[ "$_BACKUP" -eq "1" ]]; then
    echo "Backup Blocky"
    backup_blocky
elif [[ "$_CHECK" -eq "1" ]]; then
    echo "Self checking Blocky"
    self_checking
elif [[ "$_UNINSTALL" -eq "1" ]]; then
    echo "Uninstall Blocky"
    uninstall_blocky
else
    init
fi


