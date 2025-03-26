#!/bin/bash

# Step 1: Update system and install required dependencies
echo "Updating system and installing dependencies..."
sudo apt update
sudo apt install -y vnstat jq ufw bc git

# Step 2: Set up vnstat for the default network interface
INTERFACE=$(ip route | grep default | awk '{print $5}')
echo "Setting up vnstat for interface: $INTERFACE"
sudo vnstat -u -i $INTERFACE
sudo systemctl enable vnstat
sudo systemctl start vnstat

# Step 3: Download files from GitHub repository
echo "Downloading files from GitHub repository..."
REPO_URL="https://raw.githubusercontent.com/Tyga-x/TrafficCap-VPS/main"
sudo mkdir -p /usr/local/bin/cap-vps
sudo wget -O /usr/local/bin/cap-vps/bandwidth_limit.sh "$REPO_URL/bandwidth_limit.sh"
sudo chmod +x /usr/local/bin/cap-vps/bandwidth_limit.sh

# Step 4: Create the global command script (cap-vps)
echo "Creating the 'cap-vps' global command..."
echo '#!/bin/bash' > cap-vps
echo 'bash /usr/local/bin/cap-vps/bandwidth_limit.sh' >> cap-vps
sudo mv cap-vps /usr/local/bin/
sudo chmod +x /usr/local/bin/cap-vps

# Step 5: Initialize tracking files
echo "Initializing tracking files..."
sudo touch /home/ubuntu/bandwidth_start
sudo touch /home/ubuntu/bandwidth_firewall_applied
sudo chmod 644 /home/ubuntu/bandwidth_start
sudo chmod 644 /home/ubuntu/bandwidth_firewall_applied

# Step 6: Set default bandwidth limit (optional)
echo "Setting default bandwidth limit (10TB)..."
DEFAULT_LIMIT_BYTES=10000000000000 # 10TB in bytes
echo "$DEFAULT_LIMIT_BYTES" > /home/ubuntu/bandwidth_limit

# Step 7: Enable UFW and allow SSH
echo "Enabling UFW and allowing SSH..."
sudo ufw allow ssh
sudo ufw enable

# Completion message
echo ""
echo "Installation complete!"
echo "You can now access the Bandwidth Limiter menu by running 'cap-vps' in the terminal."
