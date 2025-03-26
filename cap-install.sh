#!/bin/bash

# Step 0: Clean up old files and directories (if they exist)
echo "Cleaning up old files and directories..."
sudo rm -rf /usr/local/bin/cap-vps-scripts/
sudo rm -f /usr/local/bin/cap-vps
sudo rm -f /home/ubuntu/bandwidth_start
sudo rm -f /home/ubuntu/bandwidth_firewall_applied
sudo rm -f /home/ubuntu/bandwidth_limit
sudo rm -f /home/ubuntu/renewal_cycle

# Step 1: Update system and install required dependencies
echo "Updating system and installing dependencies..."
sudo apt update
sudo apt install -y vnstat jq ufw bc git

# Step 2: Set up vnstat for the default network interface
INTERFACE=$(ip route | grep default | awk '{print $5}')
if [[ -z "$INTERFACE" ]]; then
    echo "Error: Could not detect the default network interface. Exiting."
    exit 1
fi
echo "Setting up vnstat for interface: $INTERFACE"

# Check if the interface already exists in vnstat
if ! sudo vnstat --iflist | grep -q "$INTERFACE"; then
    sudo vnstat --add -i "$INTERFACE"
fi

sudo systemctl enable vnstat
sudo systemctl start vnstat

# Step 3: Download files from GitHub repository
echo "Downloading files from GitHub repository..."
REPO_URL="https://raw.githubusercontent.com/Tyga-x/TrafficCap-VPS/main"
sudo mkdir -p /usr/local/bin/cap-vps-scripts
sudo wget -O /usr/local/bin/cap-vps-scripts/bandwidth_limit.sh "$REPO_URL/bandwidth_limit.sh"
sudo wget -O /usr/local/bin/cap-vps-scripts/uninstall.sh "$REPO_URL/uninstall.sh"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download the scripts. Exiting."
    exit 1
fi
sudo chmod +x /usr/local/bin/cap-vps-scripts/bandwidth_limit.sh
sudo chmod +x /usr/local/bin/cap-vps-scripts/uninstall.sh

# Step 4: Create the global command script (cap-vps)
echo "Creating the 'cap-vps' global command..."
if [[ -d "/usr/local/bin/cap-vps" ]]; then
    sudo rm -rf /usr/local/bin/cap-vps # Remove conflicting directory
fi
echo '#!/bin/bash' > cap-vps
echo 'bash /usr/local/bin/cap-vps-scripts/bandwidth_limit.sh' >> cap-vps
sudo mv cap-vps /usr/local/bin/
sudo chmod +x /usr/local/bin/cap-vps

# Step 5: Initialize tracking files
echo "Initializing tracking files..."
sudo touch /home/ubuntu/bandwidth_start
sudo touch /home/ubuntu/bandwidth_firewall_applied
sudo chmod 644 /home/ubuntu/bandwidth_start
sudo chmod 644 /home/ubuntu/bandwidth_firewall_applied

# Step 6: Enable UFW and allow SSH
echo "Enabling UFW and allowing SSH..."
sudo ufw allow ssh
sudo ufw --force enable

# Completion message
echo ""
echo "Installation complete!"
echo "You can now access the Bandwidth Limiter menu by running 'cap-vps' in the terminal."
