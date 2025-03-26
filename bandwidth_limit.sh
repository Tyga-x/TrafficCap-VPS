#!/bin/bash

INTERFACE=$(ip route | grep default | awk '{print $5}')
START_DATE_FILE="/home/ubuntu/bandwidth_start"
FIREWALL_RULES_APPLIED="/home/ubuntu/bandwidth_firewall_applied"

# Function to convert bytes to human-readable format
convert_bytes() {
    local bytes=$1
    if [ $bytes -ge 1000000000000 ]; then
        echo "$(echo "scale=2; $bytes / 1000000000000" | bc) TB"
    elif [ $bytes -ge 1000000000 ]; then
        echo "$(echo "scale=2; $bytes / 1000000000" | bc) GB"
    elif [ $bytes -ge 1000000 ]; then
        echo "$(echo "scale=2; $bytes / 1000000" | bc) MB"
    else
        echo "$bytes B"
    fi
}

# Menu-driven interface
show_menu() {
    echo "===== Bandwidth Limiter Menu ====="
    echo "1. Add Bandwidth Limit"
    echo "2. Reset Data Limit and Renew"
    echo "3. Uninstall Script"
    echo "4. Exit"
    read -p "Enter your choice: " choice

    case $choice in
        1)
            add_bandwidth_limit
            ;;
        2)
            reset_data_limit
            ;;
        3)
            uninstall_script
            ;;
        4)
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            show_menu
            ;;
    esac
}

add_bandwidth_limit() {
    read -p "Enter bandwidth limit (in TB): " limit_tb
    LIMIT_BYTES=$(echo "$limit_tb * 1000000000000" | bc)
    echo "Setting bandwidth limit to $limit_tb TB ($LIMIT_BYTES bytes)..."
    echo "$LIMIT_BYTES" > /home/ubuntu/bandwidth_limit
    echo "Bandwidth limit set successfully!"
    show_menu
}

reset_data_limit() {
    echo "Resetting data limit and renewing 30-day cycle..."
    date +%Y-%m-%d > "$START_DATE_FILE"
    rm -f "$FIREWALL_RULES_APPLIED"
    sudo ufw allow out to any
    sudo ufw allow in from any
    echo "Data limit reset and renewed successfully!"
    show_menu
}

uninstall_script() {
    echo "Uninstalling script..."
    sudo bash /path/to/uninstall.sh
    exit 0
}

# Load the current bandwidth limit
if [ -f "/home/ubuntu/bandwidth_limit" ]; then
    LIMIT_BYTES=$(cat /home/ubuntu/bandwidth_limit)
else
    LIMIT_BYTES=10000000000000 # Default: 10TB
fi

# Show the menu
show_menu
