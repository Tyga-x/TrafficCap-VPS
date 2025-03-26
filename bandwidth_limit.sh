#!/bin/bash

# Variables
START_DATE_FILE="/home/ubuntu/bandwidth_start"
FIREWALL_RULES_APPLIED="/home/ubuntu/bandwidth_firewall_applied"
BANDWIDTH_LIMIT_FILE="/home/ubuntu/bandwidth_limit"
RENEWAL_CYCLE_FILE="/home/ubuntu/renewal_cycle"

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

# Initialize start date and renewal cycle if not exists
if [[ ! -f "$START_DATE_FILE" ]]; then
    date +%Y-%m-%d > "$START_DATE_FILE"
fi
if [[ ! -f "$RENEWAL_CYCLE_FILE" ]]; then
    echo "30" > "$RENEWAL_CYCLE_FILE" # Default: 30-day cycle
fi

# Load the current bandwidth limit (if set)
if [[ -f "$BANDWIDTH_LIMIT_FILE" ]]; then
    LIMIT_BYTES=$(cat "$BANDWIDTH_LIMIT_FILE")
else
    LIMIT_BYTES=0 # No limit set
fi

# Load the renewal cycle duration
RENEWAL_DAYS=$(cat "$RENEWAL_CYCLE_FILE")

# Get all available interfaces monitored by vnstat
INTERFACES=$(sudo vnstat --iflist | grep -oP 'Available interfaces: \K.*' | tr ' ' ',')

# Function to calculate total usage across all interfaces
calculate_total_usage() {
    local start_date=$1
    local interfaces=$2
    local total_rx=0
    local total_tx=0

    # Split interfaces into an array
    IFS=',' read -r -a interface_array <<< "$interfaces"

    # Loop through each interface and sum up rx/tx
    for interface in "${interface_array[@]}"; do
        vnstat_output=$(vnstat --begin "$start_date" -i "$interface" --json 2>/dev/null)

        # Check if vnstat output is valid
        if [[ -z "$vnstat_output" || "$vnstat_output" == "{}" ]]; then
            echo "No vnstat data available for interface $interface."
            continue
        fi

        # Parse the JSON output using jq
        rx=$(echo "$vnstat_output" | jq -r '.interfaces[0].traffic.total.rx // 0' 2>/dev/null)
        tx=$(echo "$vnstat_output" | jq -r '.interfaces[0].traffic.total.tx // 0' 2>/dev/null)

        # Add to totals
        total_rx=$((total_rx + rx))
        total_tx=$((total_tx + tx))
    done

    # Return total usage
    echo $((total_rx + total_tx))
}

# Calculate total data used since start date
start_date=$(cat "$START_DATE_FILE")
total_bytes=$(calculate_total_usage "$start_date" "$INTERFACES")

# Convert bytes to human-readable format
total_hr=$(convert_bytes "$total_bytes")
limit_hr=$(convert_bytes "$LIMIT_BYTES")

# Log usage and limit
echo "Total Usage: $total_hr"
if [[ $LIMIT_BYTES -eq 0 ]]; then
    echo "No bandwidth limit is currently set."
else
    echo "Bandwidth Limit: $limit_hr"
fi

# Enforce bandwidth limit if set
if [[ $LIMIT_BYTES -gt 0 ]]; then
    if (( total_bytes >= LIMIT_BYTES )); then
        if [[ ! -f "$FIREWALL_RULES_APPLIED" ]]; then
            echo "Bandwidth limit reached ($total_hr / $limit_hr). Blocking traffic..."
            sudo ufw default deny incoming
            sudo ufw default deny outgoing
            sudo ufw allow ssh # Allow SSH access for management
            sudo ufw reload # Ensure rules are applied immediately
            touch "$FIREWALL_RULES_APPLIED"
        fi
    else
        if [[ -f "$FIREWALL_RULES_APPLIED" ]]; then
            echo "Bandwidth usage is below the limit ($total_hr / $limit_hr). Allowing traffic..."
            sudo ufw default allow incoming
            sudo ufw default allow outgoing
            sudo ufw reload # Ensure rules are applied immediately
            rm -f "$FIREWALL_RULES_APPLIED"
        fi
    fi
else
    echo "No bandwidth limit is configured. Traffic is unrestricted."
    sudo ufw default allow incoming
    sudo ufw default allow outgoing
    sudo ufw reload # Ensure rules are applied immediately
fi

# Real-Time Data Usage (Optional)
show_real_time_usage() {
    echo "Fetching real-time bandwidth usage..."
    while true; do
        # Use iptables to monitor real-time traffic
        rx_bytes=$(sudo iptables -L INPUT -v -x -n | awk '/eth/{print $2}')
        tx_bytes=$(sudo iptables -L OUTPUT -v -x -n | awk '/eth/{print $2}')

        total_bytes=$((rx_bytes + tx_bytes))
        total_hr=$(convert_bytes "$total_bytes")
        echo "Real-Time Usage: $total_hr"

        sleep 5 # Refresh every 5 seconds
    done
}

# Menu-driven interface
show_menu() {
    echo "===== Bandwidth Limiter Menu ====="
    echo "1. Add Bandwidth Limit and Renewal Cycle"
    echo "2. Reset Data Limit and Renew"
    echo "3. Uninstall Script"
    echo "4. Show Real-Time Usage"
    echo "5. Exit"
    read -p "Enter your choice: " choice

    case $choice in
        1)
            add_bandwidth_and_renewal_limit
            ;;
        2)
            reset_data_limit
            ;;
        3)
            uninstall_script
            ;;
        4)
            show_real_time_usage
            ;;
        5)
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            show_menu
            ;;
    esac
}

# Add Bandwidth Limit and Renewal Cycle
add_bandwidth_and_renewal_limit() {
    echo "Enter bandwidth limit:"
    read -p "Value: " limit_value
    read -p "Unit (GB/TB): " limit_unit

    if [[ "$limit_unit" =~ ^(GB|gb)$ ]]; then
        LIMIT_BYTES=$(echo "$limit_value * 1000000000" | bc)
    elif [[ "$limit_unit" =~ ^(TB|tb)$ ]]; then
        LIMIT_BYTES=$(echo "$limit_value * 1000000000000" | bc)
    else
        echo "Invalid unit. Please enter 'GB' or 'TB'."
        return
    fi

    echo "$LIMIT_BYTES" > "$BANDWIDTH_LIMIT_FILE"
    echo "Bandwidth limit set to $limit_value $limit_unit ($(convert_bytes $LIMIT_BYTES))."

    echo "Enter renewal cycle duration (in days, e.g., 30, 60):"
    read -p "Renewal Cycle (days): " renewal_days

    if [[ "$renewal_days" =~ ^[0-9]+$ && "$renewal_days" -gt 0 ]]; then
        echo "$renewal_days" > "$RENEWAL_CYCLE_FILE"
        echo "Renewal cycle set to $renewal_days days."
    else
        echo "Invalid input. Renewal cycle must be a positive integer."
        return
    fi

    show_menu
}

# Reset Data Limit and Renew
reset_data_limit() {
    echo "Resetting data limit and renewing cycle..."
    date +%Y-%m-%d > "$START_DATE_FILE"
    rm -f "$FIREWALL_RULES_APPLIED"
    sudo ufw default allow incoming
    sudo ufw default allow outgoing
    sudo ufw reload # Ensure rules are applied immediately
    echo "Data limit reset and renewed successfully!"
    show_menu
}

# Uninstall Script
uninstall_script() {
    echo "Uninstalling script..."
    sudo bash /usr/local/bin/cap-vps-scripts/cap-uninstall.sh # Corrected path
    exit 0
}

# Check if renewal cycle has expired
current_timestamp=$(date +%s)
start_date=$(cat "$START_DATE_FILE")
renewal_days=$(cat "$RENEWAL_CYCLE_FILE")
expiry_timestamp=$(date -d "$start_date +$renewal_days days" +%s)

if (( current_timestamp >= expiry_timestamp )); then
    echo "Renewal cycle expired. Resetting..."
    date +%Y-%m-%d > "$START_DATE_FILE" # Reset start date
    rm -f "$FIREWALL_RULES_APPLIED"     # Remove firewall rules flag
    sudo ufw default allow incoming
    sudo ufw default allow outgoing
    sudo ufw reload # Ensure rules are applied immediately
fi

# Show the menu
show_menu
