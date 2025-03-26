#!/bin/bash

# Variables
INTERFACE=$(ip route | grep default | awk '{print $5}')
START_DATE_FILE="/home/ubuntu/bandwidth_start"
FIREWALL_RULES_APPLIED="/home/ubuntu/bandwidth_firewall_applied"
BANDWIDTH_LIMIT_FILE="/home/ubuntu/bandwidth_limit"

# Function to convert bytes to human-readable format
convert_bytes() {
    local bytes=$1
    if (( bytes >= 1000000000000 )); then
        echo "$(echo "scale=2; $bytes / 1000000000000" | bc) TB"
    elif (( bytes >= 1000000000 )); then
        echo "$(echo "scale=2; $bytes / 1000000000" | bc) GB"
    elif (( bytes >= 1000000 )); then
        echo "$(echo "scale=2; $bytes / 1000000" | bc) MB"
    else
        echo "$bytes B"
    fi
}

# Initialize start date if not exists
if [[ ! -f "$START_DATE_FILE" ]]; then
    date +%Y-%m-%d > "$START_DATE_FILE"
fi

# Load the current bandwidth limit
if [[ -f "$BANDWIDTH_LIMIT_FILE" ]]; then
    LIMIT_BYTES=$(cat "$BANDWIDTH_LIMIT_FILE")
else
    LIMIT_BYTES=10000000000000 # Default: 10TB
fi

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

# Add Bandwidth Limit
add_bandwidth_limit() {
    echo "Enter bandwidth limit:"
    read -p "Value: " limit_value
    read -p "Unit (GB/TB): " limit_unit

    if [[ "$limit_unit" =~ ^(GB|gb)$ ]]; then
        LIMIT_BYTES=$(echo "$limit_value * 1000000000" | bc)
    elif [[ "$limit_unit" =~ ^(TB|tb)$ ]]; then
        LIMIT_BYTES=$(echo "$limit_value * 1000000000000" | bc)
    else
        echo "Invalid unit. Please enter 'GB' or 'TB'."
        add_bandwidth_limit
        return
    fi

    echo "$LIMIT_BYTES" > "$BANDWIDTH_LIMIT_FILE"
    echo "Bandwidth limit set to $limit_value $limit_unit ($(convert_bytes $LIMIT_BYTES))."
    show_menu
}

# Reset Data Limit and Renew
reset_data_limit() {
    echo "Resetting data limit and renewing 30-day cycle..."
    date +%Y-%m-%d > "$START_DATE_FILE"
    rm -f "$FIREWALL_RULES_APPLIED"
    sudo ufw allow out to any
    sudo ufw allow in from any
    echo "Data limit reset and renewed successfully!"
    show_menu
}

# Uninstall Script
uninstall_script() {
    echo "Uninstalling script..."
    sudo bash /usr/local/bin/cap-vps/uninstall.sh
    exit 0
}

# Check if 30-day cycle has expired
current_timestamp=$(date +%s)
start_date=$(cat "$START_DATE_FILE")
expiry_timestamp=$(date -d "$start_date +30 days" +%s)

if (( current_timestamp >= expiry_timestamp )); then
    echo "30-day cycle expired. Resetting..."
    date +%Y-%m-%d > "$START_DATE_FILE" # Reset start date
    rm -f "$FIREWALL_RULES_APPLIED"     # Remove firewall rules flag
    sudo ufw allow out to any
    sudo ufw allow in from any
fi

# Calculate total data used since start date
total_bytes=$(vnstat --begin "$start_date" -i "$INTERFACE" --json 2>/dev/null | jq -r '.interfaces[0].traffic.total.rx + .interfaces[0].traffic.total.tx // 0')

# Convert bytes to human-readable format
total_hr=$(convert_bytes "$total_bytes")
limit_hr=$(convert_bytes "$LIMIT_BYTES")

# Log usage and limit
echo "Total Usage: $total_hr"
echo "Bandwidth Limit: $limit_hr"

if (( total_bytes >= LIMIT_BYTES )); then
    if [[ ! -f "$FIREWALL_RULES_APPLIED" ]]; then
        echo "Bandwidth limit reached ($total_hr / $limit_hr). Blocking traffic..."
        sudo ufw default deny incoming
        sudo ufw default deny outgoing
        sudo ufw allow ssh # Allow SSH access for management
        touch "$FIREWALL_RULES_APPLIED"
    fi
else
    if [[ -f "$FIREWALL_RULES_APPLIED" ]]; then
        echo "Bandwidth usage is below the limit ($total_hr / $limit_hr). Allowing traffic..."
        sudo ufw default allow incoming
        sudo ufw default allow outgoing
        rm -f "$FIREWALL_RULES_APPLIED"
    fi
fi

# Show the menu
show_menu
