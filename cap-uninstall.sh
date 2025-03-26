#!/bin/bash

# Step 1: Remove the main script directory
echo "Removing main script files..."
sudo rm -rf /usr/local/bin/cap-vps/

# Step 2: Remove the global 'cap-vps' command
echo "Removing the global 'cap-vps' command..."
sudo rm -f /usr/local/bin/cap-vps

# Step 3: Remove tracking files
echo "Removing tracking files..."
sudo rm -f /home/ubuntu/bandwidth_start
sudo rm -f /home/ubuntu/bandwidth_firewall_applied
sudo rm -f /home/ubuntu/bandwidth_limit

# Step 4: Reset UFW rules
echo "Resetting UFW rules..."
sudo ufw reset
sudo systemctl disable ufw
sudo systemctl stop ufw

# Step 5: Remove vnstat configuration (optional)
echo "Removing vnstat configuration..."
sudo systemctl stop vnstat
sudo systemctl disable vnstat
sudo apt remove -y vnstat

# Step 6: Remove dependencies (optional)
echo "Removing dependencies (vnstat, jq, bc)..."
sudo apt remove -y jq bc

# Step 7: Clean up unused packages
echo "Cleaning up unused packages..."
sudo apt autoremove -y

# Completion message
echo ""
echo "Uninstallation complete!"
echo "All components of the Bandwidth Limiter have been removed."
