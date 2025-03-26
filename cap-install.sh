#!/bin/bash

# Update and install dependencies
echo "Installing required dependencies..."
sudo apt update
sudo apt install -y vnstat jq ufw

# Set up vnstat for the default interface (eth0 or ens3)
INTERFACE=$(ip route | grep default | awk '{print $5}')
sudo vnstat -u -i $INTERFACE

# Create necessary directories and files
sudo mkdir -p /usr/local/bin/cap-vps
sudo cp bandwidth_limit.sh /usr/local/bin/cap-vps/bandwidth_limit.sh
sudo chmod +x /usr/local/bin/cap-vps/bandwidth_limit.sh

# Copy the global command script
sudo cp cap-vps /usr/local/bin/cap-vps
sudo chmod +x /usr/local/bin/cap-vps

echo "Installation complete! Run 'cap-vps' to access the menu."
