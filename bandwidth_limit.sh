#!/bin/bash

# Variables
BANDWIDTH_LIMIT_FILE="/home/ubuntu/bandwidth_limit"
RENEWAL_CYCLE_FILE="/home/ubuntu/renewal_cycle"
FIREWALL_RULES_APPLIED="/home/ubuntu/bandwidth_firewall_applied"

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

# Initialize renewal cycle if not exists
if [[ ! -f "$RENEWAL_CYCLE_FILE" ]]; then
    echo "30" > "$RENEWAL_CYCLE_FILE" # Default: 30-day cycle
fi

# Load the current bandwidth limit and start date (if set)
if [[ -f "$BANDWIDTH_LIMIT_FILE" ]]; then
    LIMIT_INFO=$(cat "$BANDWIDTH_LIMIT_FILE")
    LIMIT_BYTES=$(echo "$LIMIT_INFO" | awk '{print $1}')
    START_DATE=$(echo "$LIMIT_INFO" | awk '{print $2}')
else
    LIMIT_BYTES=0 # No limit set
    START_DATE=$(date +%Y-%m-%d) # Default to today's date
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

        # Validate parsed values
        if [[ -z "$rx" || "$rx" == "null" ]]; then
            rx=0
        fi
        if [[ -z "$tx" || "$tx" == "null" ]]; then
            tx=0
        fi

        # Add to totals
        total_rx=$((total_rx + rx))
        total_tx=$((total_tx + tx))
    done

    # Return total usage
    echo $((total_rx + total_tx))
}

# Calculate total data used since start date
total_bytes=$(calculate_total_usage "$START_DATE" "$INTERFACES")

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
        # Fetch real-time usage for all interfaces
        for interface in $(sudo vnstat --iflist | grep -oP 'Available interfaces: \K.*' | tr ' ' ','); do
            vnstat_output=$(vnstat --oneline -i "$interface" 2>/dev/null)

            # Parse the output
            rx=$(echo "$vnstat_output" | awk -F';' '{print $4}')
            tx=$(echo "$vnstat_output" | awk -F';' '{print $5}')

            # Convert to bytes (assuming values are in human-readable format)
            rx_bytes=$(convert_to_bytes "$rx")
            tx_bytes=$(convert_to_bytes "$tx")

            total_bytes=$((rx_bytes + tx_bytes))
            total_hr=$(convert_bytes "$total_bytes")

            echo "Interface: $interface, Real-Time Usage: $total_hr"
        done

        sleep 5 # Refresh every 5 seconds
    done
}

# Helper function to convert human-readable sizes to bytes
convert_to_bytes() {
    local size=$1
    if [[ "$size" =~ ^([0-9]+(\.[0-9]+)?)\ *(GiB|MiB|KiB|B)$ ]]; then
        value=${BASH_REMATCH[1]}
        unit=${BASH_REMATCH[3]}

        case "$unit" in
            GiB) echo $(echo "$value * 1024^3" | bc) ;;
            MiB) echo $(echo "$value * 1024^2" | bc) ;;
            KiB) echo $(echo "$value * 1024" | bc) ;;
            B) echo "$value" ;;
            *) echo 0 ;;
        esac
    else
        echo 0
    fi
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

    # Set the start date to today
    START_DATE=$(date +%Y-%m-%d)

    # Save the limit and start date to the file
    echo "$LIMIT_BYTES $START_DATE" > "$BANDWIDTH_LIMIT_FILE"
    echo "Bandwidth limit set to $limit_value $limit_unit ($(convert_bytes $LIMIT_BYTES))."
    echo "Start date set to $START_DATE."

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

    # Reset start date to today
    START_DATE=$(date +%Y-%m-%d)
    echo "New start date set to $START_DATE."

    # Remove the bandwidth limit file
    rm -f "$BANDWIDTH_LIMIT_FILE"
    rm -f "$FIREWALL_RULES_APPLIED"

    # Reset firewall rules
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
expiry_timestamp=$(date -d "$START_DATE +$RENEWAL_DAYS days" +%s)

if (( current_timestamp >= expiry_timestamp )); then
    echo "Renewal cycle expired. Resetting..."

    # Reset start date to today
    START_DATE=$(date +%Y-%m-%d)
    echo "New start date set to $START_DATE."

    # Remove the bandwidth limit file and firewall rules flag
    rm -f "$BANDWIDTH_LIMIT_FILE"
    rm -f "$FIREWALL_RULES_APPLIED"

    # Reset firewall rules
    sudo ufw default allow incoming
    sudo ufw default allow outgoing
    sudo ufw reload # Ensure rules are applied immediately
fi

# Show the menu
show_menu
