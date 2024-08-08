#!/bin/bash
# Enable/Disable Blocky on target Linux system

# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd); cd $SCRIPT_PATH

# Variables
# ---------------------------------------------------\
BACKUP_DIR="$SCRIPT_PATH/backup"

# Functions
# ---------------------------------------------------\

# Create folder if not exists
create_folder() {
    local folder=$1
    if [ ! -d $folder ]; then
        mkdir -p $folder
    fi
}

# Check if a unit exists
unit_exists() {
    local unit_name=$1
    systemctl list-unit-files | grep -q "^${unit_name}"
    return $?
}

# Check if a unit is active
check_unit_status() {
    local unit_name=$1
    if systemctl is-active --quiet $unit_name; then
        echo "$unit_name active."
    else
        echo "$unit_name not active."
    fi
}

# Enable unit $1
enable_unit() {
    local unit_name=$1
    if unit_exists $unit_name; then
        systemctl enable --now $unit_name
        echo "$unit_name enabled and started."
        check_unit_status $unit_name
    else
        echo "$unit_name not found."
    fi
}

# Enable units
enable_units() {
    echo "Enabling blocky services..."

    if unit_exists "blocky.service"; then
        enable_unit "blocky.service"
    else
        echo "blocky.service not found."
        if [ -f $BACKUP_DIR/blocky.service ]; then
            cp $BACKUP_DIR/blocky.service /etc/systemd/system
            echo "Restored blocky.service from backup."
            enable_unit "blocky.service"
        fi
    fi

    if unit_exists "blocky-delay.timer"; then
        echo "blocky-delay.timer already exists."
    else
        echo "blocky-delay.timer not found."
        if [ -f $BACKUP_DIR/blocky-delay.timer ]; then
            cp $BACKUP_DIR/blocky-delay.timer /etc/systemd/system
            echo "Restored blocky-delay.timer from backup."
        fi
    fi

    if unit_exists "blocky-delay.service"; then
        enable_unit "blocky-delay.service"
    else
        echo "blocky-delay.service does not exist."
        if [ -f $BACKUP_DIR/blocky-delay.service ]; then
            cp $BACKUP_DIR/blocky-delay.service /etc/systemd/system
            echo "Restored blocky-delay.service from backup."
            enable_unit "blocky-delay.service"
        fi
    fi

    systemctl daemon-reload

}

# Disable units
disable_units() {
    echo "Disabling blocky services..."

    create_folder $BACKUP_DIR

    if unit_exists "blocky.service"; then
        systemctl stop blocky.service
        systemctl disable blocky.service
        echo "blocky.service stopped and disabled."
        check_unit_status "blocky.service"
        mv /etc/systemd/system/blocky.service $BACKUP_DIR
    else
        echo "blocky.service not found."
    fi

    if unit_exists "blocky-delay.timer"; then
        systemctl disable --now blocky-delay.timer
        echo "blocky-delay.timer disabled."
        check_unit_status "blocky-delay.timer"
        mv /etc/systemd/system/blocky-delay.timer $BACKUP_DIR
    else
        echo "blocky-delay.timer not found."
    fi

    if unit_exists "blocky-delay.service"; then
        systemctl disable --now blocky-delay.service
        echo "blocky-delay.service disabled."
        check_unit_status "blocky-delay.service"
        mv /etc/systemd/system/blocky-delay.service $BACKUP_DIR
    else
        echo "blocky-delay.service not found."
    fi

    systemctl daemon-reload
    echo "Backup files are stored in $BACKUP_DIR"


}

# Check if argument is passed
if [[ -z $1 ]]; then
    echo "Errot: need to pass argument -e (enable) or -d (disable)"
    exit 1
fi

# Check the arguments
case "$1" in
    -e)
        enable_units
        ;;
    -d)
        disable_units
        ;;
    *)
        echo "Error: Unknown argument $1"
        echo "Use -e for enabling or -d for disabling blocky service and timer."
        exit 1
        ;;
esac
