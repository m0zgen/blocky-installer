#!/bin/bash
# Enable/Disable Blocky on target Linux system

# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Functions
# ---------------------------------------------------\

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
        echo "$unit_name активен."
    else
        echo "$unit_name не активен."
    fi
}

# Enable units
enable_units() {
    echo "Enabling blocky services..."

    if unit_exists "blocky.service"; then
        systemctl enable blocky.service
        systemctl start blocky.service
        echo "blocky.service enabled and started."
        check_unit_status "blocky.service"
    else
        echo "blocky.service not found."
    fi

    if unit_exists "blocky-delay.timer"; then
        systemctl enable --now blocky-delay.timer
        echo "blocky-delay.timer enabled and started."
        check_unit_status "blocky-delay.timer"
    else
        echo "blocky-delay.timer not found."
    fi

    if unit_exists "blocky-delay.service"; then
        systemctl enable --now blocky-delay.service
        echo "blocky-delay.service enabled and started."
        check_unit_status "blocky-delay.service"
    else
        echo "blocky-delay.service does not exist."
    fi
}

# Disable units
disable_units() {
    echo "Disabling blocky services..."

    if unit_exists "blocky.service"; then
        systemctl stop blocky.service
        systemctl disable blocky.service
        echo "blocky.service stopped and disabled."
        check_unit_status "blocky.service"
    else
        echo "blocky.service not found."
    fi

    if unit_exists "blocky-delay.timer"; then
        systemctl disable --now blocky-delay.timer
        echo "blocky-delay.timer disabled."
        check_unit_status "blocky-delay.timer"
    else
        echo "blocky-delay.timer not found."
    fi

    if unit_exists "blocky-delay.service"; then
        systemctl disable --now blocky-delay.service
        echo "blocky-delay.service disabled."
        check_unit_status "blocky-delay.service"
    else
        echo "blocky-delay.service not found."
    fi
}

# Проверка, передан ли аргумент
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
